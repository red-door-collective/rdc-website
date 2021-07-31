module Page.Glossary exposing (..)

import Browser.Dom as Dom
import Design
import Element exposing (Element, centerX, fill, image, maximum, minimum, padding, paragraph, px, spacing, text, textColumn, width)
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import FeatherIcons
import Html.Attributes
import Palette
import Session exposing (Session)
import Task


type alias Model =
    { session : Session
    , showAnchor : Maybe Term
    }


type alias Term =
    { id : String
    , name : String
    , definition : String
    , link : Maybe String
    }


terms =
    [ Term "action-network" "Action Network" "Another organizing tool, this is set-up and run through the Middle TN DSA account and requires some steps to implement. We have initially used it with our Pressure Campaign in February 2021. Part of an AN campaign requires writing one or more letters and thank you responses. Then we collect targets and collect email contacts. Then we publish the campaign and elicit signatures through social media and personal contact with coalition partners. It’s beneficial to include coalition partners within the planning process to include their logos and have them boost for greater visibility." Nothing
    , Term "agitation" "Agitation" "This is not pestering, annoying or bothering someone with “bad faith” attacks. Agitation is asking probing questions to identify self-interest in potential leaders. It is reminding the person who they wish to be and encouraging them to make the necessary steps to do so. It is holding a conversation with the specific goal of activating their imagination and guiding them to action." Nothing
    , Term "data committee" "Data Committee" "Our data committee works to collect the information and insight into the climate of evictions in Nashville. Filing a detainer warrant is the first step a landlord (or property manager) will take to begin the eviction process. Our team focuses on collecting the pertinent information that is found in these detainers: plaintiffs, attorneys, court dates, addresses and names of the defendants. In addition we collect information of closed cases such as verdicts, presiding judge names, monetary judgements sought. With this information, the data team seeks to find contact information for the defendants, to build phone outreach and inform them of their rights when being evicted. In addition, the Data committee creates graphs, maps, charts and visuals to better define the housing crisis in Davidson county." Nothing
    , Term "default-of-defendant" "Default of Defendant" "Legalese to state the defendant (tenant) or their lawyer were not present for their court date and a letter for extension was not filed. This typically results in a judgement awarded to the plaintiff (landlord) and means that a writ of restitution is likely to be filed with the sheriff’s office to complete the eviction process." Nothing
    , Term "detainer-warrant" "Detainer Warrant" "In the eviction process, after a 14-day notice to evict (which may be waived within a TN tenant’s lease), the landlord or property manager files a detainer warrant through the County Circuit Court Clerk. In Davidson county, this is Richard Rooker (2021). Once the detainer is filed, a process server delivers the warrant to the defendant’s address. While it is suggested they hand the warrant to the defendant, it is not required. Warrants can be posted on doors and may be served within one week of the defendant’s court date." Nothing
    , Term "one-on-one" "One-on-one" "A vital tool in organizing. This is a very personalized individual conversation, with a loose agenda. The purpose of one-on-ones is twofold: To build a relationship and to agitate towards organizing. We use one-on-ones it two primary committees: Organizing and Outreach. We must constantly be building relationships, develop trust in one another and the leaders we meet through organizing." Nothing
    , Term "phone-banking" "Phone-banking" "This is an organizing tool developed to reach large numbers of individuals. By organizing phone-banking sessions we make calls or text individuals for a variety of reasons. Most used by three committees in Red Door Collective: Organizing, Outreach and Communications" Nothing
    , Term "tenant-union" "Tenant Union" "A collection of renters (tenants) that are working together to develop plans and take action (!) to make REAL change, together. Individually we are unable to build the power to force change and a union is the best way to collectively move to make demands (and take the power)." Nothing
    , Term "text-banking" "Text-banking" "Similar to phone-banking. We use a tool called Spoke to generate and distribute mass texts to a wide group of individuals. Not as personal as a phone call, but useful for sending concise messages or reminders. Commonly used in all committees within Red Door Collective." Nothing
    , Term "hotline" "Hotline" "This is our Google Voice number. When tenants call the hotline, they are directed to a voicemail. They can also send texts to this number. Should be considered a tool to connect with tenants. Response to hotline calls and texts should be handled by committees working with these neighbors: Organizing and Outreach." Nothing
    , Term "section-8-housing" "Section 8 Housing" "The Housing Choice Vouchers Program (often referred to as “Section 8”) is the federal government's primary program to provide housing for very low-income families, as well as the elderly and disabled. It provides qualifying families with assistance in paying their monthly rent" Nothing
    , Term "hrdc" "Housing Resource Diversionary Court (HRDC)" "This is the L.E.G.A.C.Y Court that Judge Bell created (Let Every Goal Achieve Continuous Yields). “Provides tools to support and foster mutual trust between landlords and tenants while seeking CARES Grant relief money” (however the applications for CARES relief money is now closed…they’re distributing money through MAC now)" Nothing
    , Term "mdha" "Metropolitan Development and Housing Agency (MDHA)" "Affordable housing agency." (Just "http://www.nashville-mdha.org/")
    , Term "ncrc" "Nashville Conflict Resolution Center (NCRC)" "Mediation service between landlords and tenants" (Just "https://nashvilleconflict.org/what-is-mediation/")
    , Term "noah" "Nashville Organized for Action and Hope (NOAH)" "Faith-based housing justice group." (Just "https://www.noahtn.org/affordable_housing1")
    , Term "nlihc" "National Low Income Housing Coalition (NLIHC)" "Housing policy advocacy group." (Just "https://nlihc.org/rental-assistance")
    , Term "mac" "Metropolitan Action Commission (MAC)" "Administers the Emergency Rental Assistance program as part of its HOPE (Housing, Opportunity, Partnership and Employment) Program. This housing assistance “will help renters impacted by COVID-19 catch up on past due payments that are behind as much as 12 months” and this can be rent or utilities" (Just "https://www.nashville.gov/Services/Frequently-Asked-Question-Center.aspx?sid=838")
    , Term "united-way-help-line" "United Way Help Line" "United Way is acting as a grant administrator for both State and Local CARES programs. United Way is not able to provide funds or assistance directly to individuals and families" (Just "https://www.nashvilleresponsefund.com/individuals")
    , Term "department-of-human-service" "Department of Human Services" "Government department in charge of distributing TANF reserve money" (Just "https://law.justia.com/codes/tennessee/2010/title-71/chapter-1/part-1/71-1-105/")
    , Term "lsc" "Legal Services Corporation (LSC)" "an independent nonprofit established by Congress in 1974 to provide financial support for civil legal aid to low-income Americans. LSC promotes equal access to justice by providing funding to 132 independent non-profit legal aid programs in every state, the District of Columbia, and US Territories." (Just "https://www.lsc.gov/")
    , Term "tanf" "TANF Reserve (Temporary Assistance for Needy Families)" "In fall 2019, the media reported that Tennessee had accumulated over $700 million of federal money related to the Temporary Assistance for Needy Families (TANF) program. Typically, federal grants have \" use it or lose it \" provisions where states lose the federal funding they have not spent after a specified period of time (e.g., two years). TANF, however, is unusually flexible in allowing states to keep the grant funding they have not spent forever without limitation. Because Tennessee has spent a small portion of its federal grant in recent years, the unspent funds have carried over each year and built up to the $700+ million balance." (Just "https://comptroller.tn.gov/office-functions/research-and-education-accountability/collections/tanf-inquiry.html ")
    , Term "pbc" "People’s Budget Coalition (PBC)" "The Nashville People’s Budget Coalition is building a Nashville where public safety includes communities with fully funded education, access to housing and health care, and freedom from policing and jails." (Just "https://nashvillepeoplesbudget.org/")
    ]


init : Maybe String -> Session -> ( Model, Cmd Msg )
init fragment session =
    let
        match =
            case fragment of
                Just termId ->
                    List.head <| List.filter (\term -> term.id == termId) terms

                Nothing ->
                    Nothing
    in
    ( { session = session
      , showAnchor = Nothing
      }
    , case match of
        Just term ->
            Dom.getElement term.id
                |> Task.andThen (\info -> Dom.setViewport 0 info.element.y)
                |> Task.attempt ScrollToTerm

        Nothing ->
            Cmd.none
    )


type Msg
    = MouseEnteredTerm Term
    | MouseLeftTerm
    | ScrollToTerm (Result Dom.Error ())


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        MouseEnteredTerm term ->
            ( { model | showAnchor = Just term }, Cmd.none )

        MouseLeftTerm ->
            ( { model | showAnchor = Nothing }, Cmd.none )

        ScrollToTerm _ ->
            ( model, Cmd.none )


view : Model -> { title : String, content : Element Msg }
view model =
    { title = "Glossary", content = viewGlossary model }


header =
    [ Font.size 24, Font.bold, Font.color Palette.blackLight ]


viewTerm : Maybe Term -> Term -> List (Element Msg)
viewTerm hoveredTerm ({ name, definition, link } as term) =
    let
        hovering =
            hoveredTerm == Just term

        hoveredAttrs =
            [ Events.onMouseEnter (MouseEnteredTerm term)
            , Events.onMouseLeave MouseLeftTerm
            , Element.htmlAttribute (Html.Attributes.id term.id)
            , Font.size 28
            ]
                ++ (if hovering then
                        [ Element.onLeft
                            (Design.headerLink
                                [ Element.centerY
                                , Element.paddingXY 2 0
                                ]
                                { url = "#" ++ term.id
                                , label =
                                    Element.html
                                        (FeatherIcons.link
                                            |> FeatherIcons.toHtml []
                                        )
                                }
                            )
                        ]

                    else
                        []
                   )

        linkableTerm =
            Element.el hoveredAttrs (text name)
    in
    [ paragraph header
        [ case link of
            Just url ->
                Design.externalLink []
                    { url = url
                    , fontSize = 28
                    , label = linkableTerm
                    , hovering = hovering
                    }

            Nothing ->
                linkableTerm
        ]
    , paragraph [] [ text definition ]
    ]


viewGlossary : Model -> Element Msg
viewGlossary model =
    Element.textColumn [ centerX, width (fill |> maximum 675 |> minimum 400), spacing 20, Font.size 18, padding 20 ]
        (List.concat (List.map (viewTerm model.showAnchor) terms))


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
