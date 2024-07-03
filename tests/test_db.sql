BEGIN;

CREATE TABLE alembic_version (
    version_num VARCHAR(32) NOT NULL, 
    CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num)
);

-- Running upgrade  -> 4df3919e6542

CREATE TABLE addresses (
    text VARCHAR(255) NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (text)
);

CREATE TABLE attorneys (
    id SERIAL NOT NULL, 
    name VARCHAR(255) NOT NULL, 
    aliases VARCHAR(255)[] DEFAULT '{}' NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id)
);

CREATE TABLE courtrooms (
    id SERIAL NOT NULL, 
    name VARCHAR(255) NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id)
);

CREATE TABLE judges (
    id SERIAL NOT NULL, 
    name VARCHAR(255) NOT NULL, 
    aliases VARCHAR(255)[] DEFAULT '{}' NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id)
);

CREATE TABLE phone_number_verifications (
    id SERIAL NOT NULL, 
    caller_name VARCHAR(255), 
    caller_type_id INTEGER, 
    name_error_code INTEGER, 
    carrier_error_code INTEGER, 
    mobile_country_code VARCHAR(10), 
    mobile_network_code VARCHAR(10), 
    carrier_name VARCHAR(255), 
    phone_type VARCHAR(10), 
    country_code VARCHAR(10), 
    national_format VARCHAR(30), 
    phone_number VARCHAR(30), 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    UNIQUE (phone_number)
);

CREATE TABLE plaintiffs (
    id SERIAL NOT NULL, 
    name VARCHAR(255) NOT NULL, 
    aliases VARCHAR(255)[] DEFAULT '{}' NOT NULL, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id)
);

CREATE TABLE role (
    id SERIAL NOT NULL, 
    name VARCHAR(80), 
    description VARCHAR(255), 
    PRIMARY KEY (id), 
    UNIQUE (name)
);

CREATE TABLE "user" (
    id SERIAL NOT NULL, 
    email VARCHAR(255), 
    first_name VARCHAR(255) NOT NULL, 
    last_name VARCHAR(255) NOT NULL, 
    password VARCHAR(255) NOT NULL, 
    last_login_at TIMESTAMP WITHOUT TIME ZONE, 
    current_login_at TIMESTAMP WITHOUT TIME ZONE, 
    last_login_ip VARCHAR(100), 
    current_login_ip VARCHAR(100), 
    login_count INTEGER, 
    active BOOLEAN, 
    fs_uniquifier VARCHAR(255) NOT NULL, 
    confirmed_at TIMESTAMP WITHOUT TIME ZONE, 
    preferred_navigation_id INTEGER DEFAULT '0' NOT NULL, 
    PRIMARY KEY (id), 
    UNIQUE (email), 
    UNIQUE (fs_uniquifier)
);

CREATE TABLE cases (
    docket_id VARCHAR(255) NOT NULL, 
    order_number BIGINT NOT NULL, 
    file_date DATE, 
    status_id INTEGER, 
    plaintiff_id INTEGER, 
    plaintiff_attorney_id INTEGER, 
    type VARCHAR(50), 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    address VARCHAR(255), 
    address_certainty FLOAT, 
    court_date_recurring_id INTEGER, 
    amount_claimed NUMERIC, 
    claims_possession BOOLEAN, 
    is_cares BOOLEAN, 
    is_legacy BOOLEAN, 
    nonpayment BOOLEAN, 
    notes TEXT, 
    document_image_path VARCHAR, 
    last_pleading_documents_check TIMESTAMP WITHOUT TIME ZONE, 
    pleading_document_check_was_successful BOOLEAN, 
    pleading_document_check_mismatched_html TEXT, 
    last_edited_by_id INTEGER, 
    audit_status_id INTEGER, 
    PRIMARY KEY (docket_id), 
    FOREIGN KEY(last_edited_by_id) REFERENCES "user" (id), 
    FOREIGN KEY(plaintiff_attorney_id) REFERENCES attorneys (id) ON DELETE CASCADE, 
    FOREIGN KEY(plaintiff_id) REFERENCES plaintiffs (id) ON DELETE CASCADE
);

CREATE TABLE defendants (
    id SERIAL NOT NULL, 
    first_name VARCHAR(255), 
    middle_name VARCHAR(255), 
    last_name VARCHAR(255), 
    suffix VARCHAR(255), 
    aliases VARCHAR(255)[] DEFAULT '{}' NOT NULL, 
    potential_phones VARCHAR(255), 
    verified_phone_id INTEGER, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(verified_phone_id) REFERENCES phone_number_verifications (id), 
    UNIQUE (first_name, middle_name, last_name, suffix, potential_phones)
);

CREATE TABLE roles_users (
    user_id INTEGER NOT NULL, 
    role_id INTEGER NOT NULL, 
    PRIMARY KEY (user_id, role_id), 
    FOREIGN KEY(role_id) REFERENCES role (id), 
    FOREIGN KEY(user_id) REFERENCES "user" (id)
);

CREATE TABLE detainer_warrant_addresses (
    docket_id VARCHAR(255) NOT NULL, 
    address_id VARCHAR(255) NOT NULL, 
    PRIMARY KEY (docket_id, address_id), 
    FOREIGN KEY(address_id) REFERENCES addresses (text) ON DELETE CASCADE, 
    FOREIGN KEY(docket_id) REFERENCES cases (docket_id) ON DELETE CASCADE
);

CREATE TABLE detainer_warrant_defendants (
    detainer_warrant_docket_id VARCHAR(255) NOT NULL, 
    defendant_id INTEGER NOT NULL, 
    PRIMARY KEY (detainer_warrant_docket_id, defendant_id), 
    FOREIGN KEY(defendant_id) REFERENCES defendants (id) ON DELETE CASCADE, 
    FOREIGN KEY(detainer_warrant_docket_id) REFERENCES cases (docket_id) ON DELETE CASCADE
);

CREATE TABLE hearings (
    id SERIAL NOT NULL, 
    court_date TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
    address VARCHAR(255), 
    court_order_number INTEGER, 
    continuance_on DATE, 
    docket_id VARCHAR(255) NOT NULL, 
    courtroom_id INTEGER, 
    plaintiff_id INTEGER, 
    plaintiff_attorney_id INTEGER, 
    defendant_attorney_id INTEGER, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(courtroom_id) REFERENCES courtrooms (id), 
    FOREIGN KEY(defendant_attorney_id) REFERENCES attorneys (id) ON DELETE CASCADE, 
    FOREIGN KEY(docket_id) REFERENCES cases (docket_id), 
    FOREIGN KEY(plaintiff_attorney_id) REFERENCES attorneys (id) ON DELETE CASCADE, 
    FOREIGN KEY(plaintiff_id) REFERENCES plaintiffs (id) ON DELETE CASCADE, 
    UNIQUE (court_date, docket_id)
);

CREATE TABLE pleading_documents (
    image_path VARCHAR(255) NOT NULL, 
    text TEXT, 
    kind_id INTEGER, 
    docket_id VARCHAR(255) NOT NULL, 
    status_id INTEGER, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (image_path), 
    FOREIGN KEY(docket_id) REFERENCES cases (docket_id)
);

CREATE TABLE hearing_defendants (
    hearing_id INTEGER NOT NULL, 
    defendant_id INTEGER NOT NULL, 
    PRIMARY KEY (hearing_id, defendant_id), 
    FOREIGN KEY(defendant_id) REFERENCES defendants (id) ON DELETE CASCADE, 
    FOREIGN KEY(hearing_id) REFERENCES hearings (id) ON DELETE CASCADE
);

CREATE TABLE judgments (
    id SERIAL NOT NULL, 
    in_favor_of_id INTEGER, 
    awards_possession BOOLEAN, 
    awards_fees NUMERIC, 
    entered_by_id INTEGER, 
    interest BOOLEAN, 
    interest_rate NUMERIC, 
    interest_follows_site BOOLEAN, 
    dismissal_basis_id INTEGER, 
    with_prejudice BOOLEAN, 
    file_date DATE, 
    mediation_letter BOOLEAN, 
    notes TEXT, 
    hearing_id INTEGER, 
    detainer_warrant_id VARCHAR(255) NOT NULL, 
    judge_id INTEGER, 
    plaintiff_id INTEGER, 
    plaintiff_attorney_id INTEGER, 
    defendant_attorney_id INTEGER, 
    document_image_path VARCHAR, 
    last_edited_by_id INTEGER, 
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT now() NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(defendant_attorney_id) REFERENCES attorneys (id) ON DELETE CASCADE, 
    FOREIGN KEY(detainer_warrant_id) REFERENCES cases (docket_id), 
    FOREIGN KEY(document_image_path) REFERENCES pleading_documents (image_path), 
    FOREIGN KEY(hearing_id) REFERENCES hearings (id) ON DELETE CASCADE, 
    FOREIGN KEY(judge_id) REFERENCES judges (id), 
    FOREIGN KEY(last_edited_by_id) REFERENCES "user" (id), 
    FOREIGN KEY(plaintiff_attorney_id) REFERENCES attorneys (id) ON DELETE CASCADE, 
    FOREIGN KEY(plaintiff_id) REFERENCES plaintiffs (id) ON DELETE CASCADE
);

INSERT INTO alembic_version (version_num) VALUES ('4df3919e6542') RETURNING alembic_version.version_num;

COMMIT;

