# Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
#
# Developed at SunPro, a Sun Microsystems, Inc. business.
# Permission to use, copy, modify, and distribute this
# software is freely granted, provided that this notice
# is preserved.
# Julia adaptation of fdlibm s_erf.c; see ../../THIRD_PARTY.md.
# Error function: port of the FreeBSD/fdlibm s_erf.c algorithm (the one used
# by glibc and openlibm), so results agree with the C library used by
# correctionlib to the last bit in most cases.
const ERF_ERX = 8.45062911510467529297e-01
const ERF_EFX = 1.28379167095512586316e-01
const ERF_EFX8 = 1.02703333676410069053e+00
const ERF_PP = (1.28379167095512558561e-01, -3.25042107247001499370e-01, -2.84817495755985104766e-02,
                -5.77027029648944159157e-03, -2.37630166566501626084e-05)
const ERF_QQ = (3.97917223959155352819e-01, 6.50222499887672944485e-02, 5.08130628187576562776e-03,
                1.32494738004321644526e-04, -3.96022827877536812320e-06)
const ERF_PA = (-2.36211856075265944077e-03, 4.14856118683748331666e-01, -3.72207876035701323847e-01,
                3.18346619901161753674e-01, -1.10894694282396677476e-01, 3.54783043256182359371e-02,
                -2.16637559486879084300e-03)
const ERF_QA = (1.06420880400844228286e-01, 5.40397917702171048937e-01, 7.18286544141962662868e-02,
                1.26171219808761642112e-01, 1.36370839120290507362e-02, 1.19844998467991074170e-02)
const ERF_RA = (-9.86494403484714822705e-03, -6.93858572707181764372e-01, -1.05586262253232909814e+01,
                -6.23753324503260060396e+01, -1.62396669462573470355e+02, -1.84605092906711035994e+02,
                -8.12874355063065934246e+01, -9.81432934416914548592e+00)
const ERF_SA = (1.96512716674392571292e+01, 1.37657754143519042600e+02, 4.34565877475229228821e+02,
                6.45387271733267880336e+02, 4.29008140027567833386e+02, 1.08635005541779435134e+02,
                6.57024977031928170135e+00, -6.04244152148580987438e-02)
const ERF_RB = (-9.86494292470009928597e-03, -7.99283237680523006574e-01, -1.77579549177547519889e+01,
                -1.60636384855821916062e+02, -6.37566443368389627722e+02, -1.02509513161107724954e+03,
                -4.83519191608651397019e+02)
const ERF_SB = (3.03380607434824582924e+01, 3.25792512996573918826e+02, 1.53672958608443695994e+03,
                3.19985821950859553908e+03, 2.55305040643316442583e+03, 4.74528541206955367215e+02,
                -2.24409524465858183362e+01)

function c_erf(x::Float64)::Float64
    hx = (reinterpret(UInt64, x) >> 32) % UInt32
    ix = hx & 0x7fffffff
    negative = (hx & 0x80000000) != 0
    if ix >= 0x7ff00000                      # NaN or Inf
        return (negative ? -1.0 : 1.0) + 1.0 / x
    end
    if ix < 0x3feb0000                       # |x| < 0.84375
        if ix < 0x3e300000                   # |x| < 2^-28
            ix < 0x00800000 && return 0.125 * (8.0 * x + ERF_EFX8 * x)
            return x + ERF_EFX * x
        end
        z = x * x
        p = ERF_PP
        q = ERF_QQ
        r = p[1] + z * (p[2] + z * (p[3] + z * (p[4] + z * p[5])))
        s = 1.0 + z * (q[1] + z * (q[2] + z * (q[3] + z * (q[4] + z * q[5]))))
        y = r / s
        return x + x * y
    end
    if ix < 0x3ff40000                       # 0.84375 <= |x| < 1.25
        s = abs(x) - 1.0
        a = ERF_PA
        b = ERF_QA
        P = a[1] + s * (a[2] + s * (a[3] + s * (a[4] + s * (a[5] + s * (a[6] + s * a[7])))))
        Q = 1.0 + s * (b[1] + s * (b[2] + s * (b[3] + s * (b[4] + s * (b[5] + s * b[6])))))
        return negative ? -ERF_ERX - P / Q : ERF_ERX + P / Q
    end
    if ix >= 0x40180000                      # |x| >= 6
        return negative ? 1e-300 - 1.0 : 1.0 - 1e-300
    end
    ax = abs(x)
    s = 1.0 / (ax * ax)
    if ix < 0x4006DB6E                       # |x| < 1/0.35
        a = ERF_RA
        b = ERF_SA
        R = a[1] + s * (a[2] + s * (a[3] + s * (a[4] + s * (a[5] + s * (a[6] + s * (a[7] + s * a[8]))))))
        S = 1.0 + s * (b[1] + s * (b[2] + s * (b[3] + s * (b[4] + s * (b[5] + s * (b[6] + s * (b[7] + s * b[8])))))))
    else
        a = ERF_RB
        b = ERF_SB
        R = a[1] + s * (a[2] + s * (a[3] + s * (a[4] + s * (a[5] + s * (a[6] + s * a[7])))))
        S = 1.0 + s * (b[1] + s * (b[2] + s * (b[3] + s * (b[4] + s * (b[5] + s * (b[6] + s * b[7]))))))
    end
    z = reinterpret(Float64, reinterpret(UInt64, ax) & 0xffffffff00000000)
    r = exp(-z * z - 0.5625) * exp((z - ax) * (z + ax) + R / S)
    return negative ? r / ax - 1.0 : 1.0 - r / ax
end
