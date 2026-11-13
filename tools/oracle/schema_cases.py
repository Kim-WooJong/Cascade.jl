#!/usr/bin/env python3
# correctionlib 2.8.0 cases: Copyright (c) 2021 Nick Smith, BSD-3-Clause.
# Full upstream notice and adaptation details: ../../THIRD_PARTY.md.
"""Write a correctionlib JSON file exercising every schema-v2 node type and the
TFormula cases of correctionlib's own test-suite (tests/test_core.py,
tests/test_hashprng.py, tests/test_compound.py of correctionlib 2.8.0).

The file is evaluated with correctionlib_oracle.py like the POG files, and the
Julia comparison checks Cascade.Corrections against the oracle output.

Usage: schema_cases.py OUTPUT.json
"""
import json
import sys

# (expression, number of variables, parameters) taken from correctionlib's test_tformula
TFORMULA_CASES = [
    ("23.*x", 1, []),
    ("23.*log(max(x, 0.1))", 1, []),
    ("2.2e3 + x", 1, []),
    ("-2e-3 * x", 1, []),
    ("5", 0, []),
    ("3+2", 0, []),
    (" 3 + 2 ", 0, []),
    ("3-2", 0, []),
    ("3*2", 0, []),
    ("6/2", 0, []),
    ("3^2", 0, []),
    ("4*3^2", 0, []),
    ("3^2*4", 0, []),
    ("1+2*3^4+5*2+6*2", 0, []),
    ("1+3^4*2+5*2+6*2", 0, []),
    ("3<=2", 0, []), ("2<=3", 0, []), ("3<=3", 0, []), ("3>=2", 0, []), ("2>=3", 0, []),
    ("3>=3", 0, []), ("3>2", 0, []), ("2>3", 0, []), ("3>3", 0, []), ("3<2", 0, []),
    ("2<3", 0, []), ("3<3", 0, []), ("2==3", 0, []), ("3==3", 0, []), ("2!=3", 0, []),
    ("3!=3", 0, []),
    ("1+2*3", 0, []), ("(1+2)*3", 0, []), ("2*3+1", 0, []), ("2*(3+1)", 0, []), ("4/2*3", 0, []),
    ("1-2+3", 0, []), ("(1+2)-(3+4)", 0, []), ("3/2*4+1", 0, []), ("1+3/2*4", 0, []),
    ("1+4*(3/2+5)", 0, []), ("1+2*3/4*5", 0, []), ("1+2*3/(4+5)+6", 0, []), ("100./3.*2+1", 0, []),
    ("100./3.*(4-2)+2*(3+1)", 0, []), ("2*(3*4*5)/6", 0, []), ("2*(2.5*3*3.5)*(4*4.5*5)/6", 0, []),
    ("x", 1, []), ("-x", 1, []), ("y", 2, []), ("z", 3, []), ("t", 4, []),
    ("[0]", 0, [3.0]), ("[1]", 0, [0.0, 3.0]), ("[0]+[1]*3", 0, [1.0, 3.0]),
    ("log(2)", 0, []), ("log10(2)", 0, []), ("exp(2)", 0, []), ("pow(2,0.3)", 0, []), ("erf(2.)", 0, []),
    ("max(2,1)", 0, []), ("max(1,2)", 0, []), ("cos(0.5)", 0, []), ("sin(0.5)", 0, []), ("tan(0.5)", 0, []),
    ("acos(0.5)", 0, []), ("asin(0.5)", 0, []), ("atan(0.5)", 0, []), ("atan2(-0.5, 0.5)", 0, []),
    ("cosh(0.5)", 0, []), ("sinh(0.5)", 0, []), ("tanh(0.5)", 0, []), ("acosh(2.0)", 0, []),
    ("asinh(2.0)", 0, []), ("atanh(0.5)", 0, []), ("max(max(5,3),2)", 0, []), ("max(2,max(5,3))", 0, []),
    ("-(-2.36997+0.413917*log(208))/208", 0, []),
    ("2*erf(4*(x-1))", 1, []),
    ("([0]+([1]/((log10(x)^2)+[2])))+([3]*exp(-([4]*((log10(x)-[5])*(log10(x)-[5])))))", 1,
     [1.0, 4.0, 2.0, 0.5, 2.0, 1.0]),
    ("[0]*([1]+[2]*log(x))", 1, [1.3, 4.0, 2.0]),
    ("[0]+([1]/((log10(x)^[2])+[3]))", 1, [1.3, 4.0, 1.7, 1.0]),
    ("max(0.0001,1-y*([0]+([1]*z)*(1+[2]*log(x)))/x)", 3, [1.3, 5.0, 10.0]),
    ("(-2.36997+0.413917*log(x))/x-(-2.36997+0.413917*log(208))/208", 1, []),
    ("max(0.,1.03091-0.051154*pow(x,-0.154227))-max(0.,1.03091-0.051154*pow(208.,-0.154227))", 1, []),
    ("[2]*([3]+[4]*log(max([0],min([1],x))))", 1, [1.0, 4.0, 2.0, 0.5, 2.0, 1.0, 1.0, -1.0]),
    ("((x>=[6])*(([0]+([1]/((log10(x)^2)+[2])))+([3]*exp(-([4]*((log10(x)-[5])*(log10(x)-[5])))))))+((x<[6])*[7])",
     1, [1.0, 4.0, 2.0, 0.5, 2.0, 1.0, 1.0, -1.0]),
    ("(max(0.,1.03091-0.051154*pow(x,-0.154227))-max(0.,1.03091-0.051154*pow(208.,-0.154227)))+[7]*((-2.36997+0.413917*log(x))/x-(-2.36997+0.413917*log(208))/208)",
     1, [1.0, 4.0, 2.0, 0.5, 2.0, 1.0, 1.0, -1.0]),
    ("[2]*([3]+[4]*log(max([0],min([1],x))))*1./([5]+[6]*100./3.*(max(0.,1.03091-0.051154*pow(x,-0.154227))-max(0.,1.03091-0.051154*pow(208.,-0.154227)))+[7]*((-2.36997+0.413917*log(x))/x-(-2.36997+0.413917*log(208))/208))",
     1, [1.0, 4.0, 2.0, 0.5, 2.0, 1.0, 1.0, -1.0]),
    ("100./3.*0.154227+2.36997", 0, []),
    ("exp([4]*(log10(x)-[5])*(log10(x)-[5]))", 1, [0.88524, 28.4947, 4.89135, -19.0245, 0.0227809, -6.97308]),
    ("max(0.0001,[0]+[1]/(pow(log10(x),2)+[2])+[3]*exp(-1*([4]*((log10(x)-[5])*(log10(x)-[5])))))", 1,
     [0.88524, 28.4947, 4.89135, -19.0245, 0.0227809, -6.97308]),
    ("max(0.0001,[0]+[1]/(pow(log10(x),2)+[2])+[3]*exp(-[4]*(log10(x)-[5])*(log10(x)-[5])))", 1,
     [0.88524, 28.4947, 4.89135, -19.0245, 0.0227809, -6.97308]),
    ("-[4]*(log10(x)-[5])*(log10(x)-[5])", 1, [0.945459, 2.78658, 1.65054, -48.1061, 0.0287239, -10.8759]),
    ("[2]*([3]*([4]+[5]*log(max([0],min([1],x))))*1./([6]+[7]*100./3.*(max(0.,1.03091-0.051154*pow(x,-0.154227))-max(0.,1.03091-0.051154*pow(208.,-0.154227)))+[8]*((1+0.04432-1.304*pow(max(30.,min(6500.,x)),-0.4624)+(0+1.724*log(max(30.,min(6500.,x))))/max(30.,min(6500.,x)))-(1+0.04432-1.304*pow(208.,-0.4624)+(0+1.724*log(208.))/208.))))",
     1, [55, 2510, 0.997756, 1.000155, 0.979016, 0.001834, 0.982, -0.048, 1.250]),
    ("(1+0.04432+(1.724+100.))-1", 0, []), ("(1+(1.724+100.)+0.04432)-1", 0, []),
    ("((1.724+100.)+1+0.04432)-1", 0, []), ("(1+0.04432+1.724/100.)-1", 0, []),
    ("(1+1.724/100.+0.04432)-1", 0, []), ("(1.724/100.+1+0.04432)-1", 0, []),
    ("(1+0.04432+(1.724/100.))-1", 0, []), ("(1+(1.724/100.)+0.04432)-1", 0, []),
    ("((1.724/100.)+1+0.04432)-1", 0, []),
    ("0.997756*(1.000155*(0.979016+0.001834*log(max(55.,min(2510.,100.))))*1./(0.982+-0.048*100./3.*(max(0.,1.03091-0.051154*pow(100.,-0.154227))-max(0.,1.03091-0.051154*pow(208.,-0.154227)))+1.250*((1+0.04432-1.304*pow(max(30.,min(6500.,100.)),-0.4624)+(0+1.724*log(max(30.,min(6500.,100.))))/max(30.,min(6500.,100.)))-(1+0.04432-1.304*pow(208.,-0.4624)+(0+1.724*log(208.))/208.))))",
     0, []),
    ("[0]+[1]*exp(-x/[2])", 1, [0.006467, 0.02519, 77.08]),
    ("max(0.0001,1-y/x*([1]*(z-[0])*(1+[2]*log(x/30.))))", 3, [1.4, 0.453645, -0.015665]),
    ("max(0.0001,1-y*[1]*(z-[0])*(1+[2]*log(x/30.))/x)", 3, [1.4, 0.453645, -0.015665]),
    ("max(0.0001,1-y*([1]*(z-[0])*(1+[2]*log(x/30.)))/x)", 3, [1.4, 0.453645, -0.015665]),
    ("sqrt([0]*abs([0])/(x*x)+[1]*[1]*pow(x,[3])+[2]*[2])", 1, [1.326, 0.4209, 0.02223, -0.6704]),
    ("sqrt([0]*[0]/(x*x)+[1]*[1]/x+[2]*[2])", 1, [2.3, 0.20, 0.009]),
    ("([0]+[1]*x+[2]*x^2)*(x<225)+([0]+[1]*225+[2]*225^2+[3]*(x-225)+[4]*(x-225)^2+[5]*(x-225)^3)*(x>225)", 1,
     [-3.0, -3.0, -3.0, -3.0, -3.0, -3.0]),
]

# Additional expressions: every function on the full real line (domain edges -> NaN),
# operators, precedence/associativity, unary minus binding, x[i] variables.
EXTRA_CASES = [
    ("log(x)", 1, []), ("log10(x)", 1, []), ("exp(x)", 1, []), ("erf(x)", 1, []), ("sqrt(x)", 1, []),
    ("abs(x)", 1, []), ("cos(x)", 1, []), ("sin(x)", 1, []), ("tan(x)", 1, []), ("acos(x)", 1, []),
    ("asin(x)", 1, []), ("atan(x)", 1, []), ("cosh(x)", 1, []), ("sinh(x)", 1, []), ("tanh(x)", 1, []),
    ("acosh(x)", 1, []), ("asinh(x)", 1, []), ("atanh(x)", 1, []), ("erf(x/7)", 1, []), ("erf(x*0.3)", 1, []),
    ("pow(x,y)", 2, []), ("x^y", 2, []), ("atan2(x,y)", 2, []), ("max(x,y)", 2, []), ("min(x,y)", 2, []),
    ("x>y", 2, []), ("x<y", 2, []), ("x>=y", 2, []), ("x<=y", 2, []), ("x==y", 2, []), ("x!=y", 2, []),
    ("x||y", 2, []), ("x&&y", 2, []), ("x-y-z", 3, []), ("x/y/z", 3, []), ("x^y^z", 3, []),
    ("-x^2", 1, []), ("-2^2", 0, []), ("2^-x", 1, []), ("x*-y", 2, []), ("x - -1.5", 1, []),
    ("x[0]+2*x[1]-x[2]*x[3]", 4, []), ("x>0&&y>0||z<0", 3, []), ("x+y*z^t", 4, []),
    ("1.e2*x+1.5e-3", 1, []), ("x/0", 1, []), ("[0]*x+[1]", 1, [2.5, -1.0]),
]


def var(name, t):
    return {"name": name, "type": t}


def corr(name, inputs, data, generic=None):
    c = {"name": name, "version": 1, "inputs": inputs, "output": var("out", "real"), "data": data}
    if generic is not None:
        c["generic_formulas"] = generic
    return c


def formula(expr, variables, params=None):
    d = {"nodetype": "formula", "expression": expr, "parser": "TFormula", "variables": variables}
    if params:
        d["parameters"] = params
    return d


def binning(inp, edges, content, flow):
    return {"nodetype": "binning", "input": inp, "edges": edges, "content": content, "flow": flow}


def main():
    corrections = []
    xyzt = ["x", "y", "z", "t"]
    for i, (expr, nv, params) in enumerate(TFORMULA_CASES + EXTRA_CASES):
        corrections.append(corr(f"tformula_{i:03d}", [var(v, "real") for v in xyzt[:nv]],
                                formula(expr, xyzt[:nv], [float(p) for p in params])))

    # test_evaluator: binning with "inf" edge, nested categories and a formula
    corrections.append(corr("evaluator", [var("pt", "real"), var("syst", "string")], binning(
        "pt", [0.0, 20.0, 40.0, "inf"], [
            {"nodetype": "category", "input": "syst",
             "content": [{"key": "blah", "value": 1.1}, {"key": "blah2", "value": 2.2}]},
            {"nodetype": "category", "input": "syst",
             "content": [{"key": "blah2", "value": 1.3},
                         {"key": "blah3", "value": formula("0.25*x + exp([0])", ["pt"], [3.1])}]},
            1.0], "error")))
    corrections.append(corr("constant", [], 1.234))

    # Binning: uniform / non-uniform x error / clamp / value / node / wrap
    for uniform in (True, False):
        edges = {"n": 3, "low": 0.0, "high": 3.0} if uniform else [0.0, 1.0, 2.0, 3.0]
        tag = "uniform" if uniform else "edges"
        for flow in ("error", "clamp", 42.0, "wrap"):
            corrections.append(corr(f"binning_{tag}_{flow}", [var("x", "real")],
                                    binning("x", edges, [1.0, 2.0, 3.0], flow)))
        corrections.append(corr(f"binning_{tag}_flownode", [var("x", "real")],
                                binning("x", edges, [1.0, 2.0, 3.0], formula("x*x", ["x"]))))
    corrections.append(corr("binning_uniform_fine", [var("x", "real")],
                            binning("x", {"n": 7, "low": -0.3, "high": 0.4}, [float(i) for i in range(7)], 99.0)))
    corrections.append(corr("binning_int_input", [var("n", "int")],
                            binning("n", [0.0, 2.0, 5.0, 10.0], [1.0, 2.0, 3.0], "clamp")))

    # MultiBinning: mixed uniform / non-uniform axes, int axis, all flows
    for flow in ("error", "clamp", 42.0, "wrap"):
        corrections.append(corr(f"multibinning_{flow}", [var("x", "real"), var("n", "int")], {
            "nodetype": "multibinning", "inputs": ["x", "n"],
            "edges": [{"n": 3, "low": 0.0, "high": 3.0}, [0.0, 2.0, 5.0]],
            "content": [1.0, 2.0, 3.0, 4.0, 5.0, 6.0], "flow": flow}))
    corrections.append(corr("multibinning_flownode", [var("x", "real"), var("y", "real")], {
        "nodetype": "multibinning", "inputs": ["x", "y"],
        "edges": [[0.0, 1.0, 2.0], [-1.0, 0.0, 1.0, "inf"]],
        "content": [1.0, 2.0, 3.0, 4.0, 5.0, formula("x+y", ["x", "y"])],
        "flow": formula("2*x-y", ["x", "y"])}))

    # Category: int with/without default, string with node default, duplicate keys
    corrections.append(corr("category_int_default", [var("k", "int")], {
        "nodetype": "category", "input": "k",
        "content": [{"key": 0, "value": 1.0}, {"key": 5, "value": 2.0}, {"key": -3, "value": 3.0},
                    {"key": 5, "value": 9.0}], "default": 7.0}))
    corrections.append(corr("category_int_sparse", [var("k", "int")], {
        "nodetype": "category", "input": "k",
        "content": [{"key": 1, "value": 1.0}, {"key": 100000, "value": 2.0}, {"key": -2000000, "value": 3.0}]}))
    corrections.append(corr("category_str_nodedefault", [var("s", "string"), var("x", "real")], {
        "nodetype": "category", "input": "s",
        "content": [{"key": "a", "value": 1.0}, {"key": "b", "value": formula("x*2", ["x"])}],
        "default": binning("x", [0.0, 1.0], [5.0], "clamp")}))

    # FormulaRef with generic formulas (test_formularef)
    corrections.append(corr("formularef", [var("x", "real")], binning("x", [0.0, 1.0, 2.0, 3.0], [
        {"nodetype": "formularef", "index": 0, "parameters": [0.1, 0.2]},
        {"nodetype": "formularef", "index": 0, "parameters": [1.1, -0.2]},
        {"nodetype": "formularef", "index": 1, "parameters": [3.1, 0.5, 2.0]}], "clamp"),
        generic=[formula("[0] + [1]*x", ["x"]), formula("[0]*exp(-[1]*x)+[2]*log(x)", ["x"])]))

    # Transform (test_transform): real rule, int rule with rounding (half away from zero)
    corrections.append(corr("transform_real", [var("x", "real")], {
        "nodetype": "transform", "input": "x", "rule": formula("abs(x)", ["x"]),
        "content": binning("x", [0.0, 1.0, 2.0], [1.0, 2.0], "error")}))
    corrections.append(corr("transform_int", [var("n", "int"), var("x", "real")], {
        "nodetype": "transform", "input": "n",
        "rule": binning("x", [-10.0, -0.5, 0.0, 0.5, 1.5, 2.5, 10.0], [-2.5, -0.5, 0.49, 0.5, 1.5, 2.5], "clamp"),
        "content": {"nodetype": "category", "input": "n",
                    "content": [{"key": k, "value": float(10 + k)} for k in range(-3, 4)], "default": -1.0}}))
    corrections.append(corr("transform_nested", [var("x", "real"), var("y", "real")], {
        "nodetype": "transform", "input": "x", "rule": formula("x*y", ["x", "y"]),
        "content": {"nodetype": "transform", "input": "y", "rule": formula("y+x", ["x", "y"]),
                    "content": formula("x-y", ["x", "y"])}}))

    # HashPRNG (test_hashprng)
    for dist in ("stdflat", "stdnormal", "normal"):
        corrections.append(corr(f"hashprng_{dist}", [var("var1", "real"), var("var2", "real"), var("var3", "int")],
                                {"nodetype": "hashprng", "inputs": ["var1", "var2", "var3"], "distribution": dist}))
    corrections.append(corr("hashprng_many", [var(f"v{i}", "real") for i in range(6)] + [var("e", "int")],
                            {"nodetype": "hashprng", "inputs": [f"v{i}" for i in range(6)] + ["e"],
                             "distribution": "stdflat"}))
    corrections.append(corr("hashprng_one", [var("e", "int")],
                            {"nodetype": "hashprng", "inputs": ["e"], "distribution": "normal"}))

    # CompoundCorrection constituents (test_compound-like)
    corrections.append(corr("level1", [var("x", "real"), var("y", "real")], formula("1+0.1*x-0.01*y", ["x", "y"])))
    corrections.append(corr("level2", [var("x", "real")], binning("x", [-10.0, 0.0, 10.0, 100.0], [0.9, 1.1, 1.2], "clamp")))
    corrections.append(corr("level3", [var("y", "real"), var("x", "real")], formula("1+x/(abs(y)+10)", ["x", "y"])))
    compound = []
    for i, (iop, oop) in enumerate([("*", "*"), ("+", "+"), ("/", "/"), ("*", "last"), ("+", "*")]):
        compound.append({"name": f"compound_{i}", "inputs": [var("x", "real"), var("y", "real")],
                         "output": var("out", "real"), "inputs_update": ["x"], "input_op": iop,
                         "output_op": oop, "stack": ["level1", "level2", "level3"]})

    cset = {"schema_version": 2, "description": "Cascade.Corrections schema test cases",
            "corrections": corrections, "compound_corrections": compound}
    with open(sys.argv[1], "w") as f:
        json.dump(cset, f, indent=1)
    print(f"{len(corrections)} corrections, {len(compound)} compound corrections -> {sys.argv[1]}")


if __name__ == "__main__":
    main()
