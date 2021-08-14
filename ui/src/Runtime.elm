module Runtime exposing (Environment, RollbarToken, Runtime, decode, default, environment, rollbarToken)

import Json.Decode as Decode exposing (Decoder, field)


type Environment
    = Development
    | Staging
    | Production


environment : Environment -> String
environment env =
    case env of
        Development ->
            "development"

        Staging ->
            "staging"

        Production ->
            "production"


type RollbarToken
    = RollbarToken String


rollbarToken : RollbarToken -> String
rollbarToken (RollbarToken tokenStr) =
    tokenStr


type alias Runtime =
    { environment : Environment
    , rollbarToken : RollbarToken
    }


default : Runtime
default =
    { environment = Production
    , rollbarToken = RollbarToken "jibberish"
    }


decodeEnvironment : Decoder Environment
decodeEnvironment =
    Decode.string
        |> Decode.andThen
            (\key ->
                Decode.succeed <|
                    case key of
                        "development" ->
                            Development

                        "staging" ->
                            Staging

                        "production" ->
                            Production

                        _ ->
                            Production
            )


decodeToken : Decoder RollbarToken
decodeToken =
    Decode.string |> Decode.andThen (\str -> Decode.succeed (RollbarToken str))


decode : Decoder Runtime
decode =
    Decode.map2 Runtime (field "environment" decodeEnvironment) (field "rollbarToken" decodeToken)
