"""Uploads a listing photo to Cloudinary and gives back its https link."""
import cloudinary
import cloudinary.uploader
from dotenv import load_dotenv

# Reads CLOUDINARY_URL from backend/.env (cloudinary picks it up by itself).
load_dotenv()


def upload_listing_photo(photo_bytes: bytes) -> str:
    result = cloudinary.uploader.upload(
        photo_bytes,
        folder="campusconnect/listings",  # keeps our photos in one folder
        resource_type="image",
    )
    return result["secure_url"]