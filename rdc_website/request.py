from functools import cached_property

import flask
from sqlalchemy.orm import Query, Session

from .database import db


class RdcWebsiteRequest(flask.Request):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    @cached_property
    def db_session(self) -> Session:
        return db.Session()

    def q(self, *args, **kwargs) -> Query:
        return self.db_session.query(*args, **kwargs)
