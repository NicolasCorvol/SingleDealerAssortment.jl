using SingleDealerAssortment
using Documenter

DocMeta.setdocmeta!(
    SingleDealerAssortment, :DocTestSetup, :(using SingleDealerAssortment); recursive=true
)

makedocs(;
    modules=[SingleDealerAssortment],
    authors="NicolasCorvol <nicolas.corvol@eleves.enpc.fr> and contributors",
    repo="https://github.com/NicolasCorvol/SingleDealerAssortment.jl/blob/{commit}{path}#{line}",
    sitename="SingleDealerAssortment.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://NicolasCorvol.github.io/SingleDealerAssortment.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md", "math.md",
        "API reference" => "api.md",  
    ],
)

deploydocs(; repo="github.com/NicolasCorvol/SingleDealerAssortment.jl", devbranch="master")
