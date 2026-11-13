@testset "TFormula" begin
    @testset "arithmetic and precedence (correctionlib test_tformula)" begin
        @test feval_expr("5") == 5.0
        @test feval_expr(" 3 + 2 ") == 5.0
        @test feval_expr("3-2") == 1.0
        @test feval_expr("6/2") == 3.0
        @test feval_expr("3^2") == 9.0
        @test feval_expr("4*3^2") == 36.0
        @test feval_expr("3^2*4") == 36.0
        @test feval_expr("1+2*3^4+5*2+6*2") == 1 + 2 * 81 + 10 + 12
        @test feval_expr("1+3^4*2+5*2+6*2") == 1 + 2 * 81 + 10 + 12
        @test feval_expr("4/2*3") == 6.0
        @test feval_expr("1-2+3") == 2.0
        @test feval_expr("(1+2)-(3+4)") == -4.0
        @test feval_expr("3/2*4+1") == 3.0 / 2.0 * 4.0 + 1
        @test feval_expr("100./3.*2+1") == 100.0 / 3.0 * 2.0 + 1
        @test feval_expr("(1+0.04432+1.724/100.)-1") == 0.06155999999999984
        @test feval_expr("(1+0.04432+(1.724+100.))-1") == 101.76832
        @test feval_expr("2^3^2") == 512.0          # right associative
        @test feval_expr("-x^2", 3.0) == 9.0         # unary minus binds tighter than ^
        @test feval_expr("-2^2") == 4.0              # negative literal
        @test feval_expr("2^-x", 2.0) == 0.25
        @test feval_expr("x - -1.5", 1.0) == 2.5
        @test feval_expr("x*-y", 2.0, 3.0) == -6.0
        @test feval_expr("1.e2*x+1.5e-3", 1.0) == 100.0 + 1.5e-3
        @test feval_expr("2.2e3 + x", 1.0) == 2201.0
        @test feval_expr("-2e-3 * x", 2.0) == -4e-3
    end
    @testset "comparison and logic" begin
        for (e, v) in (("3<=2", 0.0), ("2<=3", 1.0), ("3<=3", 1.0), ("3>=2", 1.0), ("2>=3", 0.0), ("3>=3", 1.0),
                       ("3>2", 1.0), ("3>3", 0.0), ("2<3", 1.0), ("3<3", 0.0), ("2==3", 0.0), ("3==3", 1.0),
                       ("2!=3", 1.0), ("3!=3", 0.0), ("0||2", 1.0), ("0||0", 0.0), ("1&&2", 1.0), ("1&&0", 0.0))
            @test feval_expr(e) == v
        end
        @test feval_expr("x>0&&y>0||z<0", 1.0, -1.0, -1.0) == 1.0
    end
    @testset "variables and parameters" begin
        @test feval_expr("y", 0.0, 3.0) == 3.0
        @test feval_expr("t", 0.0, 0.0, 0.0, 3.0) == 3.0
        @test feval_expr("x[0]+2*x[1]-x[2]*x[3]", 1.0, 2.0, 3.0, 4.0) == 1.0 + 4.0 - 12.0
        @test feval_expr("[0]+[1]*3"; params = [1.0, 3.0]) == 10.0
        @test feval_expr("[ 1 ]"; params = [0.0, 3.0]) == 3.0
    end
    @testset "functions" begin
        @test feval_expr("log(2)") == log(2.0)
        @test feval_expr("log10(2)") == log10(2.0)
        @test feval_expr("exp(2)") == exp(2.0)
        @test feval_expr("pow(2,0.3)") == 2.0^0.3
        @test feval_expr("max(2,1)") == 2.0
        @test feval_expr("min(2,1)") == 1.0
        @test feval_expr("atan2(-0.5, 0.5)") == atan(-0.5, 0.5)
        @test feval_expr("atan(0.5)") == atan(0.5)
        @test feval_expr("tanh(0.5)") == tanh(0.5)
        @test feval_expr("acosh(2.0)") == acosh(2.0)
        @test feval_expr("max(max(5,3),2)") == 5.0
        # erf reference values (correctly rounded)
        @test feval_expr("erf(x)", 0.5) ≈ 0.5204998778130465 rtol = 1e-15
        @test feval_expr("erf(x)", 1.0) ≈ 0.8427007929497149 rtol = 1e-15
        @test feval_expr("erf(x)", 2.0) ≈ 0.9953222650189527 rtol = 1e-15
        @test feval_expr("erf(x)", -3.0) ≈ -0.9999779095030014 rtol = 1e-15
        @test feval_expr("erf(x)", 1e-10) ≈ 1.1283791670955126e-10 rtol = 1e-15
        @test feval_expr("erf(x)", 7.0) == 1.0
    end
    @testset "C library semantics (NaN instead of errors)" begin
        @test isnan(feval_expr("log(x)", -1.0))
        @test feval_expr("log(x)", 0.0) == -Inf
        @test isnan(feval_expr("sqrt(x)", -1.0))
        @test isnan(feval_expr("pow(x,y)", -8.0, 1 / 3))
        @test feval_expr("pow(x,y)", -2.0, 3.0) == -8.0
        @test isnan(feval_expr("acos(x)", 2.0))
        @test isnan(feval_expr("sin(x)", Inf))
        @test feval_expr("x/0", 1.0) == Inf
        @test isnan(feval_expr("max(x,y)", NaN, 1.0))   # std::max(a, b) returns a when unordered
        @test feval_expr("max(x,y)", 1.0, NaN) == 1.0
    end
    @testset "parse errors" begin
        for bad in ("1E5", "- 5", "--5", "x y", "log10 x", "max(1)", "x[ 0]", "(1+2", "1+", "")
            @test_throws CorrectionError formula_correction(bad, 1)
        end
        @test_throws CorrectionError formula_correction("[0] + 3.", 0)     # insufficient parameters
        @test_throws CorrectionError formula_correction("y", 1)            # insufficient variables
    end
end
