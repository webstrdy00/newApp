from uuid import uuid4

from fastapi import HTTPException, UploadFile, status

from app.core.config import settings


IMAGE_EXTENSION_BY_CONTENT_TYPE = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}


class StorageService:
    def save_upload(self, upload: UploadFile) -> tuple[str, str | None]:
        self.validate_image_upload(upload)

        content_type = (upload.content_type or "").lower()
        extension = IMAGE_EXTENSION_BY_CONTENT_TYPE.get(content_type, "")
        object_key = f"records/images/{uuid4().hex}{extension}"
        client = self._client()

        buckets = {bucket["Name"] for bucket in client.list_buckets().get("Buckets", [])}
        if settings.minio_bucket not in buckets:
            client.create_bucket(Bucket=settings.minio_bucket)

        upload.file.seek(0)
        client.upload_fileobj(
            upload.file,
            settings.minio_bucket,
            object_key,
            ExtraArgs={"ContentType": content_type},
        )

        public_url = f"{settings.api_public_base_url.rstrip('/')}/files/{object_key}"
        return object_key, public_url

    def get_object(self, object_key: str):
        return self._client().get_object(Bucket=settings.minio_bucket, Key=object_key)

    def delete_object(self, object_key: str) -> None:
        self._client().delete_object(Bucket=settings.minio_bucket, Key=object_key)

    def validate_image_upload(self, upload: UploadFile) -> None:
        content_type = (upload.content_type or "").lower()
        if content_type not in settings.image_upload_allowed_content_types:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="지원하지 않는 이미지 형식입니다.",
            )

        position = upload.file.tell()
        upload.file.seek(0, 2)
        size = upload.file.tell()
        upload.file.seek(position)
        if size > settings.image_upload_max_bytes:
            if settings.image_upload_max_bytes >= 1024 * 1024:
                max_size = f"{settings.image_upload_max_bytes // (1024 * 1024)}MB"
            else:
                max_size = f"{settings.image_upload_max_bytes}바이트"
            raise HTTPException(
                status_code=status.HTTP_413_CONTENT_TOO_LARGE,
                detail=f"이미지는 최대 {max_size}까지 업로드할 수 있어요.",
            )

    def _client(self):
        import boto3
        from botocore.client import Config

        return boto3.client(
            "s3",
            endpoint_url=(
                f"{'https' if settings.minio_secure else 'http'}://{settings.minio_endpoint}"
            ),
            aws_access_key_id=settings.minio_access_key,
            aws_secret_access_key=settings.minio_secret_key,
            config=Config(signature_version="s3v4"),
            region_name="us-east-1",
        )


storage_service = StorageService()
