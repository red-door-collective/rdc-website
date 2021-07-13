"""empty message

Revision ID: c9c893e7d8e0
Revises: 537789537d2a
Create Date: 2021-07-12 23:25:39.972775

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'c9c893e7d8e0'
down_revision = '537789537d2a'
branch_labels = None
depends_on = None


def upgrade():
    op.alter_column('judgements', 'claims_fees', new_column_name='awards_fees')
    op.alter_column('judgements', 'claims_possession',
                    new_column_name='awards_possession')


def downgrade():
    op.alter_column('judgements', 'awards_fees', new_column_name='claims_fees')
    op.alter_column('judgements', 'awards_possession',
                    new_column_name='claims_possession')
