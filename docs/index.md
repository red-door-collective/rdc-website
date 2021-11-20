## Eviction Tracker

[This website](https://reddoorcollective.org/) gathers public data from [Davidson County courts](https://caselink.nashville.gov/) to provide tenant-anonymized insights for eviction trends in Nashville, Tennessee.

### Technologies

The project uses a Python backend and an Elm frontend.

#### Backend

The stack:
1. [PostgreSQL](https://www.postgresql.org/)
2. [Flask](https://flask.palletsprojects.com/en/2.0.x/) (Web framework)
3. [Flask-Resty](https://flask-resty.readthedocs.io/en/latest/index.html) (REST API)
4. [APScheduler](https://apscheduler.readthedocs.io/en/3.x/) (Jobs)
5. [PDFMiner](https://pdfminersix.readthedocs.io/en/latest/) (Data Extraction)
6. [Nix](https://nixos.org/) (build system, deployment)

[Futher details about development](backend.md)

#### Frontend

The stack:
1. [elm-ui](https://package.elm-lang.org/packages/mdgriffith/elm-ui/latest/) (Styling and layout)
2. [paack-ui](https://paackeng.github.io/paack-ui/#Styles/Colors/Colors) (Opinionated design system atop Elm-UI)
3. [elm-pages](https://elm-pages.com/) (SPA framework, specialized for static sites)
4. [elm-charts](https://elm-charts.org/)

[Further details about development](frontend.md)