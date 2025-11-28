using SingleDealerAssortment
using Documenter

DocMeta.setdocmeta!(
    SingleDealerAssortment, :DocTestSetup, :(using SingleDealerAssortment); recursive=true
)

makedocs(;
    modules=[SingleDealerAssortment],
    authors="NicolasCorvol <nicolas.corvol@eleves.enpc.fr> and contributors",
    repo="https://github.com/NicolasCorvol/SingleDealerAssortment.jl",
    sitename="SingleDealerAssortment.jl",
    format=Documenter.HTML(;
        canonical="https://NicolasCorvol.github.io/SingleDealerAssortment.jl",
        edit_link="master",
        assets=String[],
    ),
    pages=["Home" => "index.md", "api.md"],
)

deploydocs(; repo="github.com/NicolasCorvol/SingleDealerAssortment.jl", devbranch="master")
