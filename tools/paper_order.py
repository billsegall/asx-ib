#!/usr/bin/env python3
"""Place, list and cancel orders on the IB *paper* gateway.

Safety rules (enforced in code, not configurable):
  * Connects only to 127.0.0.1:4002, the paper gateway. There is no host or
    port option, so this tool cannot reach the live gateway on 4001.
  * After connecting, every managed account must be a paper account (IB paper
    account ids start with "DU"). Anything else aborts before any order call.
  * Without --submit an order is only previewed (contract, account, what-if
    margin); nothing is sent.

Policy: every order needs the owner's explicit permission first, paper
included. Claude must ask before each --submit.

Usage:
  paper_order.py status
  paper_order.py order BHP BUY 10 --limit 45.10          # preview only
  paper_order.py order BHP BUY 10 --limit 45.10 --submit
  paper_order.py order BHP SELL 10 --market --submit
  paper_order.py cancel ORDER_ID
"""
import argparse
import sys

from ib_insync import IB, LimitOrder, MarketOrder, Stock

HOST = '127.0.0.1'
PAPER_PORT = 4002
CLIENT_ID = 77          # fixed id, distinct from the backend's rotating ids
PAPER_PREFIX = 'DU'


def is_paper(accounts):
    return bool(accounts) and all(a.startswith(PAPER_PREFIX) for a in accounts)


def connect():
    ib = IB()
    ib.connect(HOST, PAPER_PORT, clientId=CLIENT_ID, timeout=15)
    accounts = ib.managedAccounts()
    if not is_paper(accounts):
        ib.disconnect()
        sys.exit(f'REFUSED: gateway on {PAPER_PORT} reports non-paper '
                 f'account(s) {accounts}; no order calls made.')
    return ib, accounts[0]


def build_order(side, qty, limit, market, account):
    if market:
        order = MarketOrder(side, qty)
    else:
        order = LimitOrder(side, qty, limit)
    order.account = account
    order.tif = 'DAY'
    order.transmit = True
    return order


def cmd_status(ib, account):
    print(f'account {account} (paper)')
    for p in ib.positions(account):
        print(f'  pos  {p.contract.symbol:6} {p.position:>10g} @ {p.avgCost:.4f}')
    for t in ib.openTrades():
        o = t.order
        print(f'  open #{o.orderId} {o.action} {o.totalQuantity:g} '
              f'{t.contract.symbol} {o.orderType} {o.lmtPrice or ""} '
              f'{t.orderStatus.status}')
    for f in ib.fills():
        e = f.execution
        print(f'  fill {e.side} {e.shares:g} {f.contract.symbol} @ {e.price} {e.time}')


def cmd_order(ib, account, a):
    side = a.side.upper()
    if side not in ('BUY', 'SELL'):
        sys.exit('side must be BUY or SELL')
    if a.qty <= 0:
        sys.exit('qty must be positive')
    if a.market == (a.limit is not None):
        sys.exit('give exactly one of --limit PRICE or --market')
    contract = Stock(a.symbol.upper(), 'ASX', 'AUD')
    if not ib.qualifyContracts(contract):
        sys.exit(f'unknown ASX contract {a.symbol}')
    order = build_order(side, a.qty, a.limit, a.market, account)
    price = 'MKT' if a.market else f'LMT {a.limit}'
    print(f'{side} {a.qty} {contract.symbol} ({contract.conId}) {price} DAY '
          f'account {account} (paper)')
    if not a.submit:
        state = ib.whatIfOrder(contract, order)
        if state:
            print(f'what-if: init margin change {state.initMarginChange} '
                  f'commission {state.commission} {state.commissionCurrency}')
        print('preview only; add --submit to send')
        return
    trade = ib.placeOrder(contract, order)
    ib.sleep(3)
    print(f'sent #{trade.order.orderId}: {trade.orderStatus.status}')
    for entry in trade.log:
        if entry.message:
            print(f'  {entry.status}: {entry.message}')


def cmd_cancel(ib, account, a):
    for t in ib.openTrades():
        if t.order.orderId == a.order_id:
            ib.cancelOrder(t.order)
            ib.sleep(2)
            print(f'#{a.order_id}: {t.orderStatus.status}')
            return
    sys.exit(f'no open order #{a.order_id}')


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest='cmd', required=True)
    sub.add_parser('status')
    o = sub.add_parser('order')
    o.add_argument('symbol')
    o.add_argument('side')
    o.add_argument('qty', type=int)
    o.add_argument('--limit', type=float)
    o.add_argument('--market', action='store_true')
    o.add_argument('--submit', action='store_true')
    c = sub.add_parser('cancel')
    c.add_argument('order_id', type=int)
    a = p.parse_args(argv)

    ib, account = connect()
    try:
        if a.cmd == 'status':
            cmd_status(ib, account)
        elif a.cmd == 'order':
            cmd_order(ib, account, a)
        else:
            cmd_cancel(ib, account, a)
    finally:
        ib.disconnect()


if __name__ == '__main__':
    main()
