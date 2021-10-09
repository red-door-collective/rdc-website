"""Database module, including the SQLAlchemy database object and DB-related utilities."""
from sqlalchemy import text, func
from sqlalchemy.orm import relationship
from sqlalchemy.ext.hybrid import Comparator, hybrid_property
from .extensions import db
from datetime import datetime, date, timezone
import numbers

# Alias common SQLAlchemy names
Column = db.Column
relationship = relationship
Model = db.Model


def reference_col(tablename, nullable=False, pk_name='id', **kwargs):
    """Column that adds primary key foreign key reference.
    Usage: ::
        category_id = reference_col('category')
        category = relationship('Category', backref='categories')
    """
    return db.Column(
        db.ForeignKey('{0}.{1}'.format(tablename, pk_name)),
        nullable=nullable, **kwargs)


def in_millis(timestamp):
    return int(timestamp) * 1000


def from_millis(posix):
    return datetime.fromtimestamp(posix / 1000, tz=timezone.utc).date()


class PosixComparator(Comparator):
    def operate(self, op, other=None):
        if other is None:
            return op(self.__clause_element__())
        elif isinstance(other, numbers.Number):
            return op(self.__clause_element__(), from_millis(other))
        else:
            return op(self.__clause_element__(), other)


class Timestamped():
    _created_at = Column(db.DateTime, name="created_at",
                         nullable=False, server_default=func.now())
    _updated_at = Column(
        db.DateTime, name="updated_at",
        nullable=False, server_default=func.now(), onupdate=func.now())

    @hybrid_property
    def created_at(self):
        if self._created_at:
            return in_millis(self._created_at.timestamp())
        else:
            return None

    @created_at.comparator
    def created_at(cls):
        return PosixComparator(cls._created_at)

    @created_at.setter
    def created_at(self, posix):
        if isinstance(posix, datetime):
            self._created_at = posix
        else:
            self._created_at = from_millis(posix)

    @hybrid_property
    def updated_at(self):
        if self._updated_at:
            return in_millis(self._updated_at.timestamp())
        else:
            return None

    @updated_at.comparator
    def updated_at(cls):
        return PosixComparator(cls._updated_at)

    @updated_at.setter
    def updated_at(self, posix):
        if isinstance(posix, datetime):
            self._updated_at = posix
        else:
            self._updated_at = from_millis(posix)
