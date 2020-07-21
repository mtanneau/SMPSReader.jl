#  Copyright 2020, Mathieu Tanneau.
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

import SMPSReader

const SLPTESTSET = joinpath(@__DIR__, "slptestset")

if !isdir(SLPTESTSET)
    dest = joinpath(@__DIR__, "slptestset.zip")
    download("https://www4.uwsp.edu/math/afelt/slptestset/slptestset.zip", dest)
    run(`unzip $(dest) -d $(dirname(SLPTESTSET))`)
end

slptestset = Dict{String, SMPSReader.TwoStageStochasticProgram}()

# ==============================================================================
# slptestset/airlift

for model in ["first", "second"]
    slptestset["airlift_$(model)"] = SMPSReader.TwoStageStochasticProgram(
        SMPSReader.read_from_file(
            "$(SLPTESTSET)/airlift/AIRL";
            sto_filename = "$(SLPTESTSET)/airlift/AIRL.sto.$(model)",
        )
    )
end

# ==============================================================================
# slptestset/assets

for model in ["large", "small"]
    slptestset["assets_$(model)"] = SMPSReader.TwoStageStochasticProgram(
        SMPSReader.read_from_file(
            "$(SLPTESTSET)/assets/assets";
            sto_filename = "$(SLPTESTSET)/assets/assets.sto.$(model)",
        )
    )
end

# ==============================================================================
#   slptestset/bonds

# ERROR: Unknown section header: SCENARIOS

# for model in ["3y3", "3y4", "3y5", "3y6", "5y3", "5y4", "5y5", "5y6"]
#     slptestset["bonds_$(model)"] = SMPSReader.read_from_file(
#         "$(SLPTESTSET)/bonds/sgpf$(model)";
#         sto_filename = "$(SLPTESTSET)/bonds/sgpf$(model).sce",
#     )
# end

# ==============================================================================
# slptestset/cargo

for n in [0, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
    slptestset["cargo_$(2^n)"] = SMPSReader.TwoStageStochasticProgram(
        SMPSReader.read_from_file(
            "$(SLPTESTSET)/cargo/4node";
            sto_filename = "$(SLPTESTSET)/cargo/4node.sto.$(2^n)",
        )
    )
end

# ==============================================================================
# slptestset/chem

slptestset["chem"] = SMPSReader.TwoStageStochasticProgram(
    SMPSReader.read_from_file("$(SLPTESTSET)/chem/chem")
)

# ==============================================================================
# slptestset/electric

slptestset["electric"] = SMPSReader.TwoStageStochasticProgram(
    SMPSReader.read_from_file("$(SLPTESTSET)/electric/LandS")
)

# ==============================================================================
# slptestset/electric_3stage

# 3-stage problem.

# for sto in ["_blocks.sto", ".sto.dep", ".sto.indep"]
#     if sto == ".sto.dep"
#         continue  # ERROR: Unknown section header: SCENARIOS
#     end
#     slptestset["electric_3stage_$(sto)"] = SMPSReader.read_from_file(
#         "$(SLPTESTSET)/electric_3stage/LandS";
#         sto_filename = "$(SLPTESTSET)/electric_3stage/LandS$(sto)"
#     )
# end

# ==============================================================================
# slptestset/environ

for ext in [
    "1200", "1875", "3780", "5292", "aggr", "imp", "loose", "lrge", "xlrge"
]
    slptestset["environ_$(ext)"] = SMPSReader.TwoStageStochasticProgram(
        SMPSReader.read_from_file(
            "$(SLPTESTSET)/environ/env";
            sto_filename = "$(SLPTESTSET)/environ/env.sto.$(ext)",
        )
    )
end

# ==============================================================================
# slptestset/phone

slptestset["phone"] = SMPSReader.TwoStageStochasticProgram(
    SMPSReader.read_from_file("$(SLPTESTSET)/phone/phone")
)

# ==============================================================================
# slptestset/stocfor

# stocfor1.cor and stocfor2.cor files are corrupt. The have a space in the first
# column of each row.
for model in ["stocfor1", "stocfor2", "stocfor3"]
    if model == "stocfor2"
        cp(
            "$(SLPTESTSET)/stocfor2/stocfor2.cor",
            "$(SLPTESTSET)/stocfor2/stocfor2_FIXED.cor";
            force = true,
        )
    else
        open("$(SLPTESTSET)/$(model)/$(model)_FIXED.cor", "w") do dest
            open("$(SLPTESTSET)/$(model)/$(model).cor", "r") do src
                while !eof(src)
                    line = readline(src; keep = true)
                    write(dest, line[2:end])
                end
            end
        end
    end
    smps = SMPSReader.read_from_file(
        "$(SLPTESTSET)/$(model)/$(model)";
        cor_filename = "$(SLPTESTSET)/$(model)/$(model)_FIXED.cor"
    )
    if length(smps.tim.rows) == 2
        # TODO(odow): debug ERROR: AssertionError: i1 == 1
        # slptestset["stocfor_$(model)"] =
        #     SMPSReader.TwoStageStochasticProgram(smps)
    end
end

# ==============================================================================

slptestset

for (k, v) in slptestset
    SMPSReader.write_to_file(
        v,
        SMPSReader.StochOptFormatFile(joinpath(@__DIR__, k * ".sof.json"))
    )
end
