@testset "isolated source copy pins the executed worker launcher" begin
    mktempdir() do dir
        root = dirname(dirname(@__DIR__))
        copyroot = joinpath(dir, "source-copy"); mkpath(copyroot)
        for name in ("src", "bin", "Project.toml", "Manifest.toml")
            source = joinpath(root, name)
            ispath(source) && cp(source, joinpath(copyroot, name))
        end
        marker = joinpath(dir, "changed-entrypoint-executed")
        mutation = "write(" * repr(marker) * ", " * repr("changed") * ")" * string(Char(10))
        report = joinpath(dir, "report.json")
        script = joinpath(dir, "probe.jl")
        fixture = joinpath(@__DIR__, "fixture.jl")
        write(script, """
        include($(repr(fixture)))
        dir = $(repr(dir))
        p = batch_fixture(dir)
        work = joinpath(dir, "batch")
        m = batch_plan(RunOptions(p; workdir = work))
        id = first(m["tasks"])["id"]
        entry = joinpath($(repr(copyroot)), "bin", "cascade.jl")
        before = BP.batch_files($(repr(copyroot)))
        write(entry, $(repr(mutation)) * read(entry, String))
        after = BP.batch_files($(repr(copyroot)))
        rejected = Bool[]
        for action in (() -> batch_status(work), () -> batch_worker(work, id),
            () -> batch_run(work), () -> BP.batch_command(work, id, 1))
            push!(rejected, try action(); false catch; true end)
        end
        write($(repr(report)), JSON3.write(Dict("rejected" => rejected,
            "changed" => [k for k in keys(before) if before[k] != after[k]],
            "marker" => ispath($(repr(marker))), "attempts" => ispath(joinpath(work, "attempts")),
            "launches" => ispath(joinpath(work, "launches")))))
        """)
        log = joinpath(dir, "probe.log")
        proc = open(log, "w") do io
            run(pipeline(ignorestatus(
                `$(Base.julia_cmd()) --startup-file=no --project=$copyroot $script`); stdout = io, stderr = io))
        end
        success(proc) || println(read(log, String))
        @test success(proc)
        if isfile(report)
            r = JSON3.read(read(report, String))
            @test r["changed"] == ["bin/cascade.jl"]
            @test r["rejected"] == [true, true, true, true]
            @test !r["marker"]
            @test !r["attempts"]
            @test !r["launches"]
        end
    end
end
