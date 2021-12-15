"""empty message

Revision ID: 648aba7516f5
Revises: 0c7d2004b225
Create Date: 2021-12-13 00:55:15.260737

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '648aba7516f5'
down_revision = '0c7d2004b225'
branch_labels = None
depends_on = None


def upgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.drop_constraint('judgments_hearing_id_fkey', 'judgments', type_='foreignkey')
    op.create_foreign_key(None, 'judgments', 'hearings', ['hearing_id'], ['id'], ondelete='CASCADE')
    # ### end Alembic commands ###


def downgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.drop_constraint(None, 'judgments', type_='foreignkey')
    op.create_foreign_key('judgments_hearing_id_fkey', 'judgments', 'hearings', ['hearing_id'], ['id'])
    # ### end Alembic commands ###