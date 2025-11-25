using SingleDealerAssortment
using Documenter

DocMeta.setdocmeta!(SingleDealerAssortment, :DocTestSetup, :(using SingleDealerAssortment); recursive=true)

makedocs(;
    modules=[SingleDealerAssortment],
    authors="NicolasCorvol <nicolas.corvol@eleves.enpc.fr> and contributors",
    sitename="SingleDealerAssortment.jl",
    format=Documenter.HTML(;
        canonical="https://NicolasCorvol.github.io/SingleDealerAssortment.jl",
        edit_link="master",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/NicolasCorvol/SingleDealerAssortment.jl",
    devbranch="master",
)
