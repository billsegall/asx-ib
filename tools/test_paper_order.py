import ast
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import paper_order  # noqa: E402

SRC = pathlib.Path(paper_order.__file__).read_text()


def test_paper_port_only():
    assert paper_order.PAPER_PORT == 4002
    ints = {n.value for n in ast.walk(ast.parse(SRC))
            if isinstance(n, ast.Constant) and isinstance(n.value, int)}
    assert 4001 not in ints


def test_no_host_or_port_options():
    assert '--port' not in SRC and '--host' not in SRC


def test_is_paper():
    assert paper_order.is_paper(['DU123456'])
    assert not paper_order.is_paper(['U123456'])
    assert not paper_order.is_paper(['DU1', 'U2'])
    assert not paper_order.is_paper([])


def test_place_order_only_in_submit_branch():
    tree = ast.parse(SRC)
    fn = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'cmd_order')
    calls = [n for n in ast.walk(fn) if isinstance(n, ast.Attribute) and n.attr == 'placeOrder']
    assert len(calls) == 1
    # the preview branch returns before placeOrder
    assert SRC.index("if not a.submit:") < SRC.index("ib.placeOrder(")
