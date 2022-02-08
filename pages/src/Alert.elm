module Alert exposing (Alert, disappearing, sticky, subscriptions, text)

import Time exposing (Posix)


type Alert
    = Sticky String
    | Disappearing DisappearingAlert


type alias DisappearingAlert =
    { lifetimeInSeconds : Int
    , text : String
    }


text alert =
    case alert of
        Sticky str ->
            str

        Disappearing disappearingAlert ->
            disappearingAlert.text


sticky str =
    Sticky str


disappearing : { lifetimeInSeconds : Int, text : String } -> Alert
disappearing config =
    Disappearing
        { lifetimeInSeconds = config.lifetimeInSeconds
        , text = config.text
        }


subscriptions : { onExpiration : Posix -> msg } -> Alert -> Sub msg
subscriptions config alert =
    case alert of
        Sticky _ ->
            Sub.none

        Disappearing { lifetimeInSeconds } ->
            Time.every (toFloat lifetimeInSeconds * 1000) config.onExpiration
