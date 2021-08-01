"""empty message

Revision ID: f30cc5d13b95
Revises: 6df98408ed48
Create Date: 2021-08-01 00:26:06.428653

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'f30cc5d13b95'
down_revision = '6df98408ed48'
branch_labels = None
depends_on = None


def upgrade():
    op.create_unique_constraint(None, "districts", ["name"])


def downgrade():
    op.drop_constraint(None, "districts", ["name"])
