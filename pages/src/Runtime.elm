module Runtime exposing (Environment, RollbarToken, Runtime, codeVersion, decodeCodeVersion, decodeDate, decodeEnvironment, decodeIso8601, decodeToken, domain, domainFromHostName, environment, rollbarToken)

import Date exposing (Date)
import Iso8601
import OptimizedDecoder as Decode exposing (Decoder)
import Result
import Time exposing (Month(..), Posix)


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


environmentFromHostName : String -> Environment
environmentFromHostName hostName =
    case hostName of
        "localhost" ->
            Development

        "reddoorcollective.org" ->
            Production

        _ ->
            Production


domainFromHostName : String -> String
domainFromHostName =
    domain << environmentFromHostName


type RollbarToken
    = RollbarToken String


rollbarToken : RollbarToken -> String
rollbarToken (RollbarToken tokenStr) =
    tokenStr


type CodeVersion
    = CodeVersion String


codeVersion : CodeVersion -> String
codeVersion (CodeVersion version) =
    version


type alias Runtime =
    { environment : Environment
    , rollbarToken : RollbarToken
    , codeVersion : CodeVersion
    , today : Date
    , todayPosix : Posix
    }


default : Runtime
default =
    { environment = Production
    , rollbarToken = RollbarToken "missing"
    , codeVersion = CodeVersion "missing"
    , today = Date.fromCalendarDate 1970 Jan 1
    , todayPosix = Time.millisToPosix 0
    }


domain : Environment -> String
domain env =
    case env of
        Production ->
            "https://reddoorcollective.org"

        Staging ->
            "https://reddoorcollective.online"

        Development ->
            "http://localhost:5000"


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


decodeCodeVersion : Decoder CodeVersion
decodeCodeVersion =
    Decode.string |> Decode.andThen (\str -> Decode.succeed (CodeVersion str))


decodeDate : Decoder Date
decodeDate =
    Decode.string
        |> Decode.andThen
            (\str ->
                str
                    |> Date.fromIsoString
                    |> Result.map Decode.succeed
                    |> Result.withDefault (Decode.succeed default.today)
            )


decodeIso8601 : Decoder Posix
decodeIso8601 =
    Decode.string
        |> Decode.andThen
            (\str ->
                str
                    |> Iso8601.toTime
                    |> Result.map Decode.succeed
                    |> Result.withDefault (Decode.succeed default.todayPosix)
            )
