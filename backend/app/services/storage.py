from uuid import uuid4

from fastapi import UploadFile

from app.core.config import settings


class StorageService:
    def save_upload(self, upload: UploadFile) -> tuple[str, str | None]:
        import boto3
        from botocore.client import Config

        extension = ""
        if upload.filename and "." in upload.filename:
            extension = "." + upload.filename.rsplit(".", 1)[1].lower()
        object_key = f"records/images/{uuid4().hex}{extension}"

        client = boto3.client(
            "s3",
            endpoint_url=f"{'https' if settings.minio_secure else 'http'}://{settings.minio_endpoint}",
            aws_access_key_id=settings.minio_access_key,
            aws_secret_access_key=settings.minio_secret_key,
            config=Config(signature_version="s3v4"),
            region_name="us-east-1",
        )

        buckets = {bucket["Name"] for bucket in client.list_buckets().get("Buckets", [])}
        if settings.minio_bucket not in buckets:
            client.create_bucket(Bucket=settings.minio_bucket)

        client.upload_fileobj(
            upload.file,
            settings.minio_bucket,
            object_key,
            ExtraArgs={"ContentType": upload.content_type or "application/octet-stream"},
        )

        public_url = f"{settings.api_public_base_url.rstrip('/')}/files/{object_key}"
        return object_key, public_url

    def get_object(self, object_key: str):
        import boto3
        from botocore.client import Config

        client = boto3.client(
            "s3",
            endpoint_url=f"{'https' if settings.minio_secure else 'http'}://{settings.minio_endpoint}",
            aws_access_key_id=settings.minio_access_key,
            aws_secret_access_key=settings.minio_secret_key,
            config=Config(signature_version="s3v4"),
            region_name="us-east-1",
        )
        return client.get_object(Bucket=settings.minio_bucket, Key=object_key)


storage_service = StorageService()
