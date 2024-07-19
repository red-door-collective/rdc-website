--
-- PostgreSQL database dump
--

-- Dumped from database version 16.3 (Postgres.app)
-- Dumped by pg_dump version 16.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: addresses; Type: TABLE; Schema: public; Owner: dev-rdc
--

CREATE TABLE public.addresses (
    text character varying(255) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.addresses OWNER TO "dev-rdc";

--
-- Name: alembic_version; Type: TABLE; Schema: public; Owner: dev-rdc
--

CREATE TABLE public.alembic_version (
    version_num character varying(32) NOT NULL
);


ALTER TABLE public.alembic_version OWNER TO "dev-rdc";

--
-- Name: attorneys; Type: TABLE; Schema: public; Owner: dev-rdc
--

CREATE TABLE public.attorneys (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    aliases character varying(255)[] DEFAULT '{}'::character varying[] NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.attorneys OWNER TO "dev-rdc";

--
-- Name: attorneys_id_seq; Type: SEQUENCE; Schema: public; Owner: dev-rdc
--

CREATE SEQUENCE public.attorneys_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.attorneys_id_seq OWNER TO "dev-rdc";

--
-- Name: attorneys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dev-rdc
--

ALTER SEQUENCE public.attorneys_id_seq OWNED BY public.attorneys.id;


--
-- Name: cases; Type: TABLE; Schema: public; Owner: dev-rdc
--

CREATE TABLE public.cases (
    docket_id character varying(255) NOT NULL,
    order_number bigint NOT NULL,
    file_date date,
    status_id integer,
    plaintiff_id integer,
    plaintiff_attorney_id integer,
    type character varying(50),
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    address character varying(255),
    address_certainty double precision,
    court_date_recurring_id integer,
    amount_claimed numeric,
    claims_possession boolean,
    is_cares boolean,
    is_legacy boolean,
    nonpayment boolean,
    notes text,
    document_image_path character varying,
    last_pleading_documents_check timestamp without time zone,
    pleading_document_check_was_successful boolean,
    pleading_document_check_mismatched_html text,
    last_edited_by_id integer,
    audit_status_id integer
);


ALTER TABLE public.cases OWNER TO "dev-rdc";

--
-- Name: courtrooms; Type: TABLE; Schema: public; Owner: dev-rdc
--

CREATE TABLE public.courtrooms (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.courtrooms OWNER TO "dev-rdc";

--
-- Name: courtrooms_id_seq; Type: SEQUENCE; Schema: public; Owner: dev-rdc
--

CREATE SEQUENCE public.courtrooms_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.courtrooms_id_seq OWNER TO "dev-rdc";

--
-- Name: courtrooms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dev-rdc
--

ALTER SEQUENCE public.courtrooms_id_seq OWNED BY public.courtrooms.id;


--
-- Name: defendants; Type: TABLE; Schema: public; Owner: dev-rdc
--

CREATE TABLE public.defendants (
    id integer NOT NULL,
    first_name character varying(255),
    middle_name character varying(255),
    last_name character varying(255),
    suffix character varying(255),
    aliases character varying(255)[] DEFAULT '{}'::character varying[] NOT NULL,
    potential_phones character varying(255),
    verified_phone_id integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.defendants OWNER TO "dev-rdc";

--
-- Name: defendants_id_seq; Type: SEQUENCE; Schema: public; Owner: dev-rdc
--

CREATE SEQUENCE public.defendants_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.defendants_id_seq OWNER TO "dev-rdc";

--
-- Name: defendants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dev-rdc
--

ALTER SEQUENCE public.defendants_id_seq OWNED BY public.defendants.id;


--
-- Name: detainer_warrant_addresses; Type: TABLE; Schema: public; Owner: dev-rdc
--

CREATE TABLE public.detainer_warrant_addresses (
    docket_id character varying(255) NOT NULL,
    address_id character varying(255) NOT NULL
);


ALTER TABLE public.detainer_warrant_addresses OWNER TO "dev-rdc";

--
-- Name: detainer_warrant_defendants; Type: TABLE; Schema: public; Owner: dev-rdc
--

CREATE TABLE public.detainer_warrant_defendants (
    detainer_warrant_docket_id character varying(255) NOT NULL,
    defendant_id integer NOT NULL
);


ALTER TABLE public.detainer_warrant_defendants OWNER TO "dev-rdc";

--
-- Name: hearing_defendants; Type: TABLE; Schema: public; Owner: dev-rdc
--

CREATE TABLE public.hearing_defendants (
    hearing_id integer NOT NULL,
    defendant_id integer NOT NULL
);


ALTER TABLE public.hearing_defendants OWNER TO "dev-rdc";

--
-- Name: hearings; Type: TABLE; Schema: public; Owner: dev-rdc
--

CREATE TABLE public.hearings (
    id integer NOT NULL,
    court_date timestamp without time zone NOT NULL,
    address character varying(255),
    court_order_number integer,
    continuance_on date,
    docket_id character varying(255) NOT NULL,
    courtroom_id integer,
    plaintiff_id integer,
    plaintiff_attorney_id integer,
    defendant_attorney_id integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.hearings OWNER TO "dev-rdc";

--
-- Name: hearings_id_seq; Type: SEQUENCE; Schema: public; Owner: dev-rdc
--

CREATE SEQUENCE public.hearings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.hearings_id_seq OWNER TO "dev-rdc";

--
-- Name: hearings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dev-rdc
--

ALTER SEQUENCE public.hearings_id_seq OWNED BY public.hearings.id;


--
-- Name: judges; Type: TABLE; Schema: public; Owner: dev-rdc
--

CREATE TABLE public.judges (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    aliases character varying(255)[] DEFAULT '{}'::character varying[] NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.judges OWNER TO "dev-rdc";

--
-- Name: judges_id_seq; Type: SEQUENCE; Schema: public; Owner: dev-rdc
--

CREATE SEQUENCE public.judges_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.judges_id_seq OWNER TO "dev-rdc";

--
-- Name: judges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dev-rdc
--

ALTER SEQUENCE public.judges_id_seq OWNED BY public.judges.id;


--
-- Name: judgments; Type: TABLE; Schema: public; Owner: dev-rdc
--

CREATE TABLE public.judgments (
    id integer NOT NULL,
    in_favor_of_id integer,
    awards_possession boolean,
    awards_fees numeric,
    entered_by_id integer,
    interest boolean,
    interest_rate numeric,
    interest_follows_site boolean,
    dismissal_basis_id integer,
    with_prejudice boolean,
    file_date date,
    mediation_letter boolean,
    notes text,
    hearing_id integer,
    detainer_warrant_id character varying(255) NOT NULL,
    judge_id integer,
    plaintiff_id integer,
    plaintiff_attorney_id integer,
    defendant_attorney_id integer,
    document_image_path character varying,
    last_edited_by_id integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.judgments OWNER TO "dev-rdc";

--
-- Name: judgments_id_seq; Type: SEQUENCE; Schema: public; Owner: dev-rdc
--

CREATE SEQUENCE public.judgments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.judgments_id_seq OWNER TO "dev-rdc";

--
-- Name: judgments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dev-rdc
--

ALTER SEQUENCE public.judgments_id_seq OWNED BY public.judgments.id;


--
-- Name: phone_number_verifications; Type: TABLE; Schema: public; Owner: dev-rdc
--

CREATE TABLE public.phone_number_verifications (
    id integer NOT NULL,
    caller_name character varying(255),
    caller_type_id integer,
    name_error_code integer,
    carrier_error_code integer,
    mobile_country_code character varying(10),
    mobile_network_code character varying(10),
    carrier_name character varying(255),
    phone_type character varying(10),
    country_code character varying(10),
    national_format character varying(30),
    phone_number character varying(30),
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.phone_number_verifications OWNER TO "dev-rdc";

--
-- Name: phone_number_verifications_id_seq; Type: SEQUENCE; Schema: public; Owner: dev-rdc
--

CREATE SEQUENCE public.phone_number_verifications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.phone_number_verifications_id_seq OWNER TO "dev-rdc";

--
-- Name: phone_number_verifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dev-rdc
--

ALTER SEQUENCE public.phone_number_verifications_id_seq OWNED BY public.phone_number_verifications.id;


--
-- Name: plaintiffs; Type: TABLE; Schema: public; Owner: dev-rdc
--

CREATE TABLE public.plaintiffs (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    aliases character varying(255)[] DEFAULT '{}'::character varying[] NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.plaintiffs OWNER TO "dev-rdc";

--
-- Name: plaintiffs_id_seq; Type: SEQUENCE; Schema: public; Owner: dev-rdc
--

CREATE SEQUENCE public.plaintiffs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.plaintiffs_id_seq OWNER TO "dev-rdc";

--
-- Name: plaintiffs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dev-rdc
--

ALTER SEQUENCE public.plaintiffs_id_seq OWNED BY public.plaintiffs.id;


--
-- Name: pleading_documents; Type: TABLE; Schema: public; Owner: dev-rdc
--

CREATE TABLE public.pleading_documents (
    image_path character varying(255) NOT NULL,
    text text,
    kind_id integer,
    docket_id character varying(255) NOT NULL,
    status_id integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.pleading_documents OWNER TO "dev-rdc";

--
-- Name: role; Type: TABLE; Schema: public; Owner: dev-rdc
--

CREATE TABLE public.role (
    id integer NOT NULL,
    name character varying(80),
    description character varying(255)
);


ALTER TABLE public.role OWNER TO "dev-rdc";

--
-- Name: role_id_seq; Type: SEQUENCE; Schema: public; Owner: dev-rdc
--

CREATE SEQUENCE public.role_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.role_id_seq OWNER TO "dev-rdc";

--
-- Name: role_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dev-rdc
--

ALTER SEQUENCE public.role_id_seq OWNED BY public.role.id;


--
-- Name: roles_users; Type: TABLE; Schema: public; Owner: dev-rdc
--

CREATE TABLE public.roles_users (
    user_id integer NOT NULL,
    role_id integer NOT NULL
);


ALTER TABLE public.roles_users OWNER TO "dev-rdc";

--
-- Name: user; Type: TABLE; Schema: public; Owner: dev-rdc
--

CREATE TABLE public."user" (
    id integer NOT NULL,
    email character varying(255),
    first_name character varying(255) NOT NULL,
    last_name character varying(255) NOT NULL,
    password character varying(255) NOT NULL,
    last_login_at timestamp without time zone,
    current_login_at timestamp without time zone,
    last_login_ip character varying(100),
    current_login_ip character varying(100),
    login_count integer,
    active boolean,
    fs_uniquifier character varying(255) NOT NULL,
    confirmed_at timestamp without time zone,
    preferred_navigation_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public."user" OWNER TO "dev-rdc";

--
-- Name: user_id_seq; Type: SEQUENCE; Schema: public; Owner: dev-rdc
--

CREATE SEQUENCE public.user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_id_seq OWNER TO "dev-rdc";

--
-- Name: user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: dev-rdc
--

ALTER SEQUENCE public.user_id_seq OWNED BY public."user".id;


--
-- Name: attorneys id; Type: DEFAULT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.attorneys ALTER COLUMN id SET DEFAULT nextval('public.attorneys_id_seq'::regclass);


--
-- Name: courtrooms id; Type: DEFAULT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.courtrooms ALTER COLUMN id SET DEFAULT nextval('public.courtrooms_id_seq'::regclass);


--
-- Name: defendants id; Type: DEFAULT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.defendants ALTER COLUMN id SET DEFAULT nextval('public.defendants_id_seq'::regclass);


--
-- Name: hearings id; Type: DEFAULT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.hearings ALTER COLUMN id SET DEFAULT nextval('public.hearings_id_seq'::regclass);


--
-- Name: judges id; Type: DEFAULT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.judges ALTER COLUMN id SET DEFAULT nextval('public.judges_id_seq'::regclass);


--
-- Name: judgments id; Type: DEFAULT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.judgments ALTER COLUMN id SET DEFAULT nextval('public.judgments_id_seq'::regclass);


--
-- Name: phone_number_verifications id; Type: DEFAULT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.phone_number_verifications ALTER COLUMN id SET DEFAULT nextval('public.phone_number_verifications_id_seq'::regclass);


--
-- Name: plaintiffs id; Type: DEFAULT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.plaintiffs ALTER COLUMN id SET DEFAULT nextval('public.plaintiffs_id_seq'::regclass);


--
-- Name: role id; Type: DEFAULT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.role ALTER COLUMN id SET DEFAULT nextval('public.role_id_seq'::regclass);


--
-- Name: user id; Type: DEFAULT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public."user" ALTER COLUMN id SET DEFAULT nextval('public.user_id_seq'::regclass);


--
-- Name: addresses addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_pkey PRIMARY KEY (text);


--
-- Name: alembic_version alembic_version_pkc; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.alembic_version
    ADD CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num);


--
-- Name: attorneys attorneys_pkey; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.attorneys
    ADD CONSTRAINT attorneys_pkey PRIMARY KEY (id);


--
-- Name: cases cases_pkey; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.cases
    ADD CONSTRAINT cases_pkey PRIMARY KEY (docket_id);


--
-- Name: courtrooms courtrooms_pkey; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.courtrooms
    ADD CONSTRAINT courtrooms_pkey PRIMARY KEY (id);


--
-- Name: defendants defendants_first_name_middle_name_last_name_suffix_potentia_key; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.defendants
    ADD CONSTRAINT defendants_first_name_middle_name_last_name_suffix_potentia_key UNIQUE (first_name, middle_name, last_name, suffix, potential_phones);


--
-- Name: defendants defendants_pkey; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.defendants
    ADD CONSTRAINT defendants_pkey PRIMARY KEY (id);


--
-- Name: detainer_warrant_addresses detainer_warrant_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.detainer_warrant_addresses
    ADD CONSTRAINT detainer_warrant_addresses_pkey PRIMARY KEY (docket_id, address_id);


--
-- Name: detainer_warrant_defendants detainer_warrant_defendants_pkey; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.detainer_warrant_defendants
    ADD CONSTRAINT detainer_warrant_defendants_pkey PRIMARY KEY (detainer_warrant_docket_id, defendant_id);


--
-- Name: hearing_defendants hearing_defendants_pkey; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.hearing_defendants
    ADD CONSTRAINT hearing_defendants_pkey PRIMARY KEY (hearing_id, defendant_id);


--
-- Name: hearings hearings_court_date_docket_id_key; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.hearings
    ADD CONSTRAINT hearings_court_date_docket_id_key UNIQUE (court_date, docket_id);


--
-- Name: hearings hearings_pkey; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.hearings
    ADD CONSTRAINT hearings_pkey PRIMARY KEY (id);


--
-- Name: judges judges_pkey; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.judges
    ADD CONSTRAINT judges_pkey PRIMARY KEY (id);


--
-- Name: judgments judgments_pkey; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.judgments
    ADD CONSTRAINT judgments_pkey PRIMARY KEY (id);


--
-- Name: phone_number_verifications phone_number_verifications_phone_number_key; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.phone_number_verifications
    ADD CONSTRAINT phone_number_verifications_phone_number_key UNIQUE (phone_number);


--
-- Name: phone_number_verifications phone_number_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.phone_number_verifications
    ADD CONSTRAINT phone_number_verifications_pkey PRIMARY KEY (id);


--
-- Name: plaintiffs plaintiffs_pkey; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.plaintiffs
    ADD CONSTRAINT plaintiffs_pkey PRIMARY KEY (id);


--
-- Name: pleading_documents pleading_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.pleading_documents
    ADD CONSTRAINT pleading_documents_pkey PRIMARY KEY (image_path);


--
-- Name: role role_name_key; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.role
    ADD CONSTRAINT role_name_key UNIQUE (name);


--
-- Name: role role_pkey; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.role
    ADD CONSTRAINT role_pkey PRIMARY KEY (id);


--
-- Name: roles_users roles_users_pkey; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.roles_users
    ADD CONSTRAINT roles_users_pkey PRIMARY KEY (user_id, role_id);


--
-- Name: user user_email_key; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT user_email_key UNIQUE (email);


--
-- Name: user user_fs_uniquifier_key; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT user_fs_uniquifier_key UNIQUE (fs_uniquifier);


--
-- Name: user user_pkey; Type: CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (id);


--
-- Name: cases cases_document_image_path_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.cases
    ADD CONSTRAINT cases_document_image_path_fkey FOREIGN KEY (document_image_path) REFERENCES public.pleading_documents(image_path);


--
-- Name: cases cases_last_edited_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.cases
    ADD CONSTRAINT cases_last_edited_by_id_fkey FOREIGN KEY (last_edited_by_id) REFERENCES public."user"(id);


--
-- Name: cases cases_plaintiff_attorney_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.cases
    ADD CONSTRAINT cases_plaintiff_attorney_id_fkey FOREIGN KEY (plaintiff_attorney_id) REFERENCES public.attorneys(id) ON DELETE CASCADE;


--
-- Name: cases cases_plaintiff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.cases
    ADD CONSTRAINT cases_plaintiff_id_fkey FOREIGN KEY (plaintiff_id) REFERENCES public.plaintiffs(id) ON DELETE CASCADE;


--
-- Name: defendants defendants_verified_phone_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.defendants
    ADD CONSTRAINT defendants_verified_phone_id_fkey FOREIGN KEY (verified_phone_id) REFERENCES public.phone_number_verifications(id);


--
-- Name: detainer_warrant_addresses detainer_warrant_addresses_address_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.detainer_warrant_addresses
    ADD CONSTRAINT detainer_warrant_addresses_address_id_fkey FOREIGN KEY (address_id) REFERENCES public.addresses(text) ON DELETE CASCADE;


--
-- Name: detainer_warrant_addresses detainer_warrant_addresses_docket_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.detainer_warrant_addresses
    ADD CONSTRAINT detainer_warrant_addresses_docket_id_fkey FOREIGN KEY (docket_id) REFERENCES public.cases(docket_id) ON DELETE CASCADE;


--
-- Name: detainer_warrant_defendants detainer_warrant_defendants_defendant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.detainer_warrant_defendants
    ADD CONSTRAINT detainer_warrant_defendants_defendant_id_fkey FOREIGN KEY (defendant_id) REFERENCES public.defendants(id) ON DELETE CASCADE;


--
-- Name: detainer_warrant_defendants detainer_warrant_defendants_detainer_warrant_docket_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.detainer_warrant_defendants
    ADD CONSTRAINT detainer_warrant_defendants_detainer_warrant_docket_id_fkey FOREIGN KEY (detainer_warrant_docket_id) REFERENCES public.cases(docket_id) ON DELETE CASCADE;


--
-- Name: hearing_defendants hearing_defendants_defendant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.hearing_defendants
    ADD CONSTRAINT hearing_defendants_defendant_id_fkey FOREIGN KEY (defendant_id) REFERENCES public.defendants(id) ON DELETE CASCADE;


--
-- Name: hearing_defendants hearing_defendants_hearing_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.hearing_defendants
    ADD CONSTRAINT hearing_defendants_hearing_id_fkey FOREIGN KEY (hearing_id) REFERENCES public.hearings(id) ON DELETE CASCADE;


--
-- Name: hearings hearings_courtroom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.hearings
    ADD CONSTRAINT hearings_courtroom_id_fkey FOREIGN KEY (courtroom_id) REFERENCES public.courtrooms(id);


--
-- Name: hearings hearings_defendant_attorney_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.hearings
    ADD CONSTRAINT hearings_defendant_attorney_id_fkey FOREIGN KEY (defendant_attorney_id) REFERENCES public.attorneys(id) ON DELETE CASCADE;


--
-- Name: hearings hearings_docket_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.hearings
    ADD CONSTRAINT hearings_docket_id_fkey FOREIGN KEY (docket_id) REFERENCES public.cases(docket_id);


--
-- Name: hearings hearings_plaintiff_attorney_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.hearings
    ADD CONSTRAINT hearings_plaintiff_attorney_id_fkey FOREIGN KEY (plaintiff_attorney_id) REFERENCES public.attorneys(id) ON DELETE CASCADE;


--
-- Name: hearings hearings_plaintiff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.hearings
    ADD CONSTRAINT hearings_plaintiff_id_fkey FOREIGN KEY (plaintiff_id) REFERENCES public.plaintiffs(id) ON DELETE CASCADE;


--
-- Name: judgments judgments_defendant_attorney_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.judgments
    ADD CONSTRAINT judgments_defendant_attorney_id_fkey FOREIGN KEY (defendant_attorney_id) REFERENCES public.attorneys(id) ON DELETE CASCADE;


--
-- Name: judgments judgments_detainer_warrant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.judgments
    ADD CONSTRAINT judgments_detainer_warrant_id_fkey FOREIGN KEY (detainer_warrant_id) REFERENCES public.cases(docket_id);


--
-- Name: judgments judgments_document_image_path_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.judgments
    ADD CONSTRAINT judgments_document_image_path_fkey FOREIGN KEY (document_image_path) REFERENCES public.pleading_documents(image_path);


--
-- Name: judgments judgments_hearing_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.judgments
    ADD CONSTRAINT judgments_hearing_id_fkey FOREIGN KEY (hearing_id) REFERENCES public.hearings(id) ON DELETE CASCADE;


--
-- Name: judgments judgments_judge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.judgments
    ADD CONSTRAINT judgments_judge_id_fkey FOREIGN KEY (judge_id) REFERENCES public.judges(id);


--
-- Name: judgments judgments_last_edited_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.judgments
    ADD CONSTRAINT judgments_last_edited_by_id_fkey FOREIGN KEY (last_edited_by_id) REFERENCES public."user"(id);


--
-- Name: judgments judgments_plaintiff_attorney_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.judgments
    ADD CONSTRAINT judgments_plaintiff_attorney_id_fkey FOREIGN KEY (plaintiff_attorney_id) REFERENCES public.attorneys(id) ON DELETE CASCADE;


--
-- Name: judgments judgments_plaintiff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.judgments
    ADD CONSTRAINT judgments_plaintiff_id_fkey FOREIGN KEY (plaintiff_id) REFERENCES public.plaintiffs(id) ON DELETE CASCADE;


--
-- Name: pleading_documents pleading_documents_docket_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.pleading_documents
    ADD CONSTRAINT pleading_documents_docket_id_fkey FOREIGN KEY (docket_id) REFERENCES public.cases(docket_id);


--
-- Name: roles_users roles_users_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.roles_users
    ADD CONSTRAINT roles_users_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.role(id);


--
-- Name: roles_users roles_users_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: dev-rdc
--

ALTER TABLE ONLY public.roles_users
    ADD CONSTRAINT roles_users_user_id_fkey FOREIGN KEY (user_id) REFERENCES public."user"(id);


--
-- PostgreSQL database dump complete
--

