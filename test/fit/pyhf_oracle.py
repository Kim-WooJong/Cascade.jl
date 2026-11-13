"""External test oracle: evaluates a workspace with pyhf and writes reference numbers.

Usage: python3 pyhf_oracle.py input.json output.json
input.json: {"workspace": {...}, "point": {name: value}, "mu_tests": [...]}
Only used by test_pyhf_crosscheck.jl (CASCADE_PYHF_ORACLE=1); never a runtime dependency.
"""
import json
import sys
import traceback

import numpy as np
import pyhf

pyhf.set_backend("numpy", pyhf.optimize.minuit_optimizer(tolerance=1e-5, strategy=2))


def flt(x):
    return float(np.asarray(x).reshape(-1)[0])


def main(inp_path, out_path):
    inp = json.load(open(inp_path))
    ws = pyhf.Workspace(inp["workspace"])
    model = ws.model(
        modifier_settings={
            "normsys": {"interpcode": "code4"},
            "histosys": {"interpcode": "code4p"},
        }
    )
    data = np.asarray(ws.data(model))
    names = model.config.par_names
    names = names() if callable(names) else list(names)
    init = [float(v) for v in model.config.suggested_init()]
    bounds = [list(map(float, b)) for b in model.config.suggested_bounds()]
    fixed = [bool(f) for f in model.config.suggested_fixed()]
    point = np.asarray([inp["point"][n] for n in names], dtype=float)
    out = {
        "pyhf_version": pyhf.__version__,
        "par_names": names,
        "init": init,
        "bounds": bounds,
        "fixed": fixed,
        "logpdf_init": flt(model.logpdf(init, data)),
        "logpdf_point": flt(model.logpdf(point, data)),
        "expected_point": np.asarray(model.expected_actualdata(point)).tolist(),
    }
    bestfit, twice_nll, res = pyhf.infer.mle.fit(
        data, model, return_uncertainties=True, return_fitted_val=True, return_result_obj=True
    )
    out["bestfit"] = np.asarray(bestfit)[:, 0].tolist()
    out["errors"] = np.asarray(bestfit)[:, 1].tolist()
    out["twice_nll"] = flt(twice_nll)
    out["covariance"] = np.asarray(res.hess_inv).tolist()
    if inp.get("mle_only", False):
        json.dump(out, open(out_path, "w"))
        return
    out["inference_optimizer"] = "minuit"
    try:
        inference(out, model, data, init, bounds, fixed, point, inp["mu_tests"])
    except pyhf.exceptions.FailedMinimization:
        # Minuit may flag nearly flat directions; retry with scipy (SLSQP)
        pyhf.set_backend("numpy", pyhf.optimize.scipy_optimizer(tolerance=1e-12))
        out["inference_optimizer"] = "scipy"
        try:
            inference(out, model, data, init, bounds, fixed, point, inp["mu_tests"])
        except Exception as exc:
            out["inference_error"] = repr(exc) + "\n" + traceback.format_exc()
    except Exception as exc:  # e.g. pyhf/minuit cannot fit a model without free parameters
        out["inference_error"] = repr(exc) + "\n" + traceback.format_exc()
    json.dump(out, open(out_path, "w"))


def inference(out, model, data, init, bounds, fixed, point, mu_tests):
    nmain = model.config.nmaindata
    a0 = pyhf.infer.calculators.generate_asimov_data(0.0, data, model, init, bounds, fixed)
    out["asimov0_main"] = np.asarray(a0)[:nmain].tolist()
    out["asimov0_logpdf_point"] = flt(model.logpdf(point, a0))
    out["tests"] = []
    for mu in mu_tests:
        q = pyhf.infer.test_statistics.qmu_tilde(mu, data, model, init, bounds, fixed)
        cls, tails, exp = pyhf.infer.hypotest(
            mu, data, model, test_stat="qtilde", return_tail_probs=True, return_expected_set=True
        )
        out["tests"].append(
            {
                "mu": mu,
                "qmu_tilde": flt(q),
                "cls": flt(cls),
                "clsb": flt(tails[0]),
                "clb": flt(tails[1]),
                "cls_expected": [flt(e) for e in exp],
            }
        )
    obs, exp = pyhf.infer.intervals.upper_limits.toms748_scan(
        data, model, 0.0, 10.0, level=0.05, rtol=1e-8, test_stat="qtilde"
    )
    out["upper_limit_obs"] = flt(obs)
    out["upper_limit_exp"] = [flt(e) for e in exp]
    out["q0"] = flt(pyhf.infer.test_statistics.q0(0.0, data, model, init, bounds, fixed))
    a1 = pyhf.infer.calculators.generate_asimov_data(1.0, data, model, init, bounds, fixed)
    out["q0_asimov"] = flt(pyhf.infer.test_statistics.q0(0.0, a1, model, init, bounds, fixed))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
