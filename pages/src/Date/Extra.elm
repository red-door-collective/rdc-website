module Date.Extra exposing (fromUSCalString)

import Date exposing (Date)
import Parser exposing ((|.), (|=), Parser, andThen, chompWhile, getChompedString, int, problem, spaces, succeed, symbol)


type alias DateComponents =
    { month : String
    , day : String
    , year : Int
    }


component : Parser String
component =
    getChompedString (chompWhile Char.isDigit)
        |> andThen checkComponent


checkComponent : String -> Parser String
checkComponent code =
    if String.length code == 2 then
        succeed code

    else
        problem "a year or month must be two digits"


dateComponents : Parser DateComponents
dateComponents =
    succeed DateComponents
        |= component
        |. symbol "/"
        |= component
        |. symbol "/"
        |= int


componentsToDate : DateComponents -> Maybe Date
componentsToDate components =
    String.fromInt components.year
        ++ "-"
        ++ components.month
        ++ "-"
        ++ components.day
        |> Date.fromIsoString
        |> Result.toMaybe


fromUSCalString : String -> Maybe Date
fromUSCalString str =
    Parser.run dateComponents str
        |> Result.toMaybe
        |> Maybe.andThen componentsToDate
