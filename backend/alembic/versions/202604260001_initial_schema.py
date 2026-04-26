"""initial schema

Revision ID: 202604260001
Revises:
Create Date: 2026-04-26
"""
from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "202604260001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    attachment_type = sa.Enum("image", "url", "youtube", name="attachment_type")

    op.create_table(
        "cooking_records",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("dish_name", sa.String(length=80), nullable=False),
        sa.Column("cooked_date", sa.Date(), nullable=False),
        sa.Column("recipe", sa.Text(), nullable=True),
        sa.Column("memo", sa.Text(), nullable=True),
        sa.Column("rating", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_cooking_records_cooked_date"), "cooking_records", ["cooked_date"], unique=False)
    op.create_index(op.f("ix_cooking_records_dish_name"), "cooking_records", ["dish_name"], unique=False)
    op.create_index(op.f("ix_cooking_records_id"), "cooking_records", ["id"], unique=False)

    op.create_table(
        "record_ingredients",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("record_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("quantity", sa.String(length=80), nullable=True),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["record_id"], ["cooking_records.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_record_ingredients_id"), "record_ingredients", ["id"], unique=False)

    op.create_table(
        "record_attachments",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("record_id", sa.Integer(), nullable=False),
        sa.Column("type", attachment_type, nullable=False),
        sa.Column("title", sa.String(length=200), nullable=True),
        sa.Column("url", sa.String(length=1000), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("thumbnail_url", sa.String(length=1000), nullable=True),
        sa.Column("object_key", sa.String(length=1000), nullable=True),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["record_id"], ["cooking_records.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_record_attachments_id"), "record_attachments", ["id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_record_attachments_id"), table_name="record_attachments")
    op.drop_table("record_attachments")
    op.drop_index(op.f("ix_record_ingredients_id"), table_name="record_ingredients")
    op.drop_table("record_ingredients")
    op.drop_index(op.f("ix_cooking_records_id"), table_name="cooking_records")
    op.drop_index(op.f("ix_cooking_records_dish_name"), table_name="cooking_records")
    op.drop_index(op.f("ix_cooking_records_cooked_date"), table_name="cooking_records")
    op.drop_table("cooking_records")
    sa.Enum(name="attachment_type").drop(op.get_bind(), checkfirst=True)
