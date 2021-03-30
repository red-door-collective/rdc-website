"""Database module, including the SQLAlchemy database object and DB-related utilities."""
from sqlalchemy import text, func
from sqlalchemy.orm import relationship
from .extensions import db

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


class Timestamped():
    created_at = Column(db.DateTime, nullable=False, server_default=func.now())
    updated_at = Column(
        db.DateTime, nullable=False, server_default=func.now(), onupdate=func.now())
