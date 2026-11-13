"""Run one explicitly requested phase; successful physics artifacts are never restarted."""
function run_phase()
    get(ENV,"CASCADE_TTBAR_REAL","0")=="1" || error("set CASCADE_TTBAR_REAL=1 explicitly on gate")
    area=abspath(ENV["CASCADE_TTBAR_AREA"]); phase=ENV["CASCADE_TTBAR_PHASE"]
    project=normpath(joinpath(@__DIR__,"../..")); p=joinpath(area,"analysis.toml")
    rp=joinpath(bundle_root(area),"analysis.toml")
    @testset "combined actual ttbar integration $phase" begin
        if phase=="prepare"
            prepare(area,project)
        elseif phase=="prepare-reuse"
            prepare_reuse(area,project)
        else
            verify_inputs(area)
            if phase=="hash-probe"
                hash_probe(area)
            elseif phase=="reduced-continue"
                run_pipeline(RunOptions(rp;workdir=joinpath(area,"reduced"),steps=[:merge,:systematics]))
            elseif phase=="original"
                ispath(joinpath(area,"original")) && error("original exists; inspect before retry")
                run_pipeline(RunOptions(p;max_files=2,workdir=joinpath(area,"original"),steps=CORE))
            elseif phase=="export"
                reduce_analysis(RunOptions(p;max_files=2);output_dir=joinpath(area,"bundle"))
            elseif phase=="reduced"
                ispath(joinpath(area,"reduced")) && error("reduced exists; inspect before retry")
                run_pipeline(RunOptions(rp;workdir=joinpath(area,"reduced"),steps=CORE))
            elseif phase=="batch"
                work=joinpath(area,"batch")
                batch_plan(RunOptions(rp;workdir=work))
                @test batch_run(work;workers=2)["complete"]
                # Publish immutable histogram/systematic result first. Fit/plot are
                # deliberately separate diagnostic consumers, not in-place edits.
                result=batch_merge(work)
                writejson(joinpath(area,"batch-result-path.json"),Dict("path"=>result))
            elseif phase=="events"
                verify_events(area)
            elseif phase=="compare"
                compare_outputs(area)
            elseif phase=="inventories"
                accept_inventories(area)
            elseif phase=="reports"
                accept_reports(area)
            elseif phase=="fitplot"
                fit_plot(area)
            elseif phase=="final"
                @test isfile(joinpath(area,"event-summary.json"))
                @test isfile(joinpath(area,"comparison-summary.json"))
                @test isfile(joinpath(area,"fit-plot-summary.json"))
                @test isfile(joinpath(area,"inventory-acceptance.json"))
                @test isfile(joinpath(area,"report-acceptance.json"))
                println("FINAL INPUT/PAYLOAD DRIFT CHECK PASSED")
            else
                error("unknown integration phase $phase")
            end
        end
    end
end
