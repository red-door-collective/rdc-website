module Email exposing (Email)

{-| An email address.
Having this as a custom type that's separate from String makes certain
mistakes impossible. Consider this function:
updateEmailAddress : Email -> String -> Http.Request
updateEmailAddress email password = ...
(The server needs your password to confirm that you should be allowed
to update the email address.)
Because Email is not a type alias for String, but is instead a separate
custom type, it is now impossible to mix up the argument order of the
email and the password. If we do, it won't compile!
If Email were instead defined as `type alias Email = String`, we could
call updateEmailAddress password email and it would compile (and never
work properly).
This way, we make it impossible for a bug like that to compile!
-}


type Email
    = Email String
