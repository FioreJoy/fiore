# backend/src/routers/posts.py

from fastapi import APIRouter, Depends, HTTPException, status, Form, UploadFile, File, Query
from typing import List, Optional, Dict, Any, Literal
import psycopg2
import os
import traceback
import json

from .. import schemas, crud, auth, utils, security
from ..database import get_db_connection
from ..utils import get_minio_url, delete_from_minio, delete_media_item_db_and_file

# REMOVE old manager: from ..connection_manager import manager
# INSTEAD, if this router needs to emit Socket.IO events, import 'sio' from socketio_manager
from ..socketio_manager import sio # Import the Socket.IO server instance

router = APIRouter(
    prefix="/posts",
    tags=["Posts"],
    dependencies=[Depends(security.get_api_key)]
)

@router.get("/trending", response_model=List[schemas.PostDisplay])
async def get_trending_posts(
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional),
        limit: int = Query(20, ge=1, le=100),
        offset: int = Query(0, ge=0)
):
    # Current placeholder implementation, using get_discover_feed as a proxy for trending
    # A dedicated trending algorithm could be different.
    print("Router: /posts/trending called, using discover feed logic.")
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        feed_items_db = crud.get_discover_feed(cursor, current_user_id, limit, offset)
        processed_feed: List[schemas.PostDisplay] = []
        for item_db in feed_items_db:
            post_data = dict(item_db)
            post_id_int = post_data['id'] # Use int for CRUD operations

            # Augment with author avatar and media URLs (already done by crud.get_discover_feed for this specific one)
            # For generic endpoints, this augmentation might be needed here.
            # Here, we re-ensure or re-fetch based on returned data.

            # Fetch author avatar (get_discover_feed already returns author_avatar as object_name)
            author_avatar_path = post_data.pop('author_avatar', None)
            post_data['author_avatar_url'] = utils.get_minio_url(author_avatar_path) if author_avatar_path else None

            # Media items (get_discover_feed already includes this, structured for PostDisplay)
            # If 'media' key contains object_names, convert to full URLs:
            if 'media' in post_data and isinstance(post_data['media'], list):
                media_list_processed = []
                for media_item_from_crud in post_data['media']:
                    if isinstance(media_item_from_crud, dict):
                        media_dict = dict(media_item_from_crud) # ensure it's a dict
                        # Ensure 'url' is populated. If CRUD already gives full URL, this is fine.
                        # If it gives object_name, we'd do utils.get_minio_url here.
                        # crud._feed.get_discover_feed already structures 'media' as List[MediaItemDisplay] compatible data including URLs.
                        media_list_processed.append(schemas.MediaItemDisplay(**media_dict))
                post_data['media'] = media_list_processed


            viewer_vote = None; is_favorited = False
            if current_user_id is not None:
                try: viewer_vote = crud.get_viewer_vote_status(cursor, current_user_id, post_id=post_id_int)
                except Exception as e: print(f"WARN feed: vote status check failed P:{post_id_int}: {e}")
                try: is_favorited = crud.get_viewer_favorite_status(cursor, current_user_id, post_id=post_id_int)
                except Exception as e: print(f"WARN feed: fav status check failed P:{post_id_int}: {e}")

            post_data['viewer_vote_type'] = 'UP' if viewer_vote is True else ('DOWN' if viewer_vote is False else None)
            post_data['viewer_has_favorited'] = is_favorited

            post_data.setdefault('upvotes', 0); post_data.setdefault('downvotes', 0); post_data.setdefault('reply_count', 0); post_data.setdefault('favorite_count', 0)
            post_data.setdefault('image_url', None)

            try: processed_feed.append(schemas.PostDisplay(**post_data))
            except Exception as pydantic_err: print(f"ERROR: Pydantic validation for trending post {post_id_int}: {pydantic_err}\nData: {post_data}")

        return processed_feed
    except psycopg2.Error as db_err: print(f"DB Error /posts/trending: {db_err}"); raise HTTPException(status_code=500, detail="Database error fetching trending posts.")
    except Exception as e: print(f"Error /posts/trending: {e}"); traceback.print_exc(); raise HTTPException(status_code=500, detail="Error fetching trending posts.")
    finally:
        if conn: conn.close()


@router.get("/{post_id}", response_model=schemas.PostDisplay)
async def get_post_details(
        post_id: int,
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional)
):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        post_relational = crud.get_post_by_id(cursor, post_id)
        if not post_relational:
            raise HTTPException(status_code=404, detail="Post not found")
        post_data = dict(post_relational)
        author_info = crud.get_user_by_id(cursor, post_data['user_id'])
        if author_info:
            post_data['author_name'] = author_info.get('username')
            author_avatar_media = crud.get_user_profile_picture_media(cursor, post_data['user_id'])
            post_data['author_avatar_url'] = utils.get_minio_url(author_avatar_media.get('minio_object_name') if author_avatar_media else None)
        else:
            post_data['author_name'] = "Unknown"; post_data['author_avatar_url'] = None

        comm_id = None; comm_name = None
        try:
            cypher_q_comm = f"MATCH (c:Community)-[:HAS_POST]->(:Post {{id: {post_id}}}) RETURN c.id as id, c.name as name LIMIT 1"
            expected_comm = [('id', 'agtype'), ('name', 'agtype')]
            comm_res = crud.execute_cypher(cursor, cypher_q_comm, fetch_one=True, expected_columns=expected_comm)
            if comm_res and isinstance(comm_res, dict):
                comm_id = comm_res.get('id'); comm_name = comm_res.get('name')
        except Exception as e: print(f"WARN: Failed fetching community link for P:{post_id}: {e}")
        post_data['community_id'] = comm_id
        post_data['community_name'] = comm_name

        try: counts = crud.get_post_counts(cursor, post_id); post_data.update(counts)
        except Exception as e: print(f"WARN get_post: counts failed P:{post_id}: {e}"); post_data.update({"reply_count": 0, "upvotes": 0, "downvotes": 0, "favorite_count": 0})

        try:
            media_items = crud.get_media_items_for_post(cursor, post_id)
            processed_media = []
            for item in media_items:
                item_dict = dict(item)
                item_dict['url'] = utils.get_minio_url(item_dict.get('minio_object_name'))
                processed_media.append(schemas.MediaItemDisplay(**item_dict))
            post_data['media'] = processed_media
        except Exception as e: print(f"WARN get_post: media failed P:{post_id}: {e}"); post_data['media'] = []

        viewer_vote = None; is_favorited = False
        if current_user_id is not None:
            try: viewer_vote = crud.get_viewer_vote_status(cursor, current_user_id, post_id=post_id)
            except Exception as e: print(f"WARN: vote status check failed P:{post_id}: {e}")
            try: is_favorited = crud.get_viewer_favorite_status(cursor, current_user_id, post_id=post_id)
            except Exception as e: print(f"WARN: fav status check failed P:{post_id}: {e}")
        post_data['viewer_vote_type'] = 'UP' if viewer_vote is True else ('DOWN' if viewer_vote is False else None)
        post_data['viewer_has_favorited'] = is_favorited
        post_data.setdefault('upvotes', 0); post_data.setdefault('downvotes', 0); post_data.setdefault('reply_count', 0); post_data.setdefault('favorite_count', 0); post_data.setdefault('image_url', None)
        return schemas.PostDisplay(**post_data)

    except HTTPException as http_exc: raise http_exc
    except psycopg2.Error as db_err: print(f"DB Error GET /posts/{post_id}: {db_err}"); raise HTTPException(status_code=500, detail="Database error")
    except Exception as e: print(f"Error GET /posts/{post_id}: {e}"); traceback.print_exc(); raise HTTPException(status_code=500, detail="Internal server error")
    finally:
        if conn: conn.close()

@router.get("", response_model=List[schemas.PostDisplay])
async def get_posts(
        current_user_id: Optional[int] = Depends(auth.get_current_user_optional),
        community_id: Optional[int] = Query(None),
        user_id: Optional[int] = Query(None),
        limit: int = Query(20, ge=1, le=100),
        offset: int = Query(0, ge=0)
):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        posts_db = crud.get_posts_db(cursor, community_id=community_id, user_id=user_id, limit=limit, offset=offset)
        processed_posts = []
        for post in posts_db:
            post_data = dict(post); post_id_int = post_data['id']; author_id_int = post_data['user_id']
            author_avatar_media = crud.get_user_profile_picture_media(cursor, author_id_int)
            post_data['author_avatar_url'] = utils.get_minio_url(author_avatar_media.get('minio_object_name') if author_avatar_media else None)
            try:
                media_items = crud.get_media_items_for_post(cursor, post_id_int)
                post_data['media'] = [ {**item, 'url': utils.get_minio_url(item.get('minio_object_name'))} for item in media_items ]
            except Exception as e: print(f"WARN list: Failed getting media P:{post_id_int}: {e}"); post_data['media'] = []
            viewer_vote = None; is_favorited = False
            if current_user_id is not None:
                try: viewer_vote = crud.get_viewer_vote_status(cursor, current_user_id, post_id=post_id_int)
                except Exception as e: print(f"WARN list: vote status check failed P:{post_id_int}: {e}")
                try: is_favorited = crud.get_viewer_favorite_status(cursor, current_user_id, post_id=post_id_int)
                except Exception as e: print(f"WARN list: fav status check failed P:{post_id_int}: {e}")
            post_data['viewer_vote_type'] = 'UP' if viewer_vote is True else ('DOWN' if viewer_vote is False else None)
            post_data['viewer_has_favorited'] = is_favorited
            post_data.setdefault('upvotes', 0); post_data.setdefault('downvotes', 0); post_data.setdefault('reply_count', 0); post_data.setdefault('favorite_count', 0); post_data.setdefault('image_url', None)
            try: processed_posts.append(schemas.PostDisplay(**post_data))
            except Exception as pydantic_err: print(f"ERROR: Pydantic validation for post {post_id_int} in list: {pydantic_err}\nData: {post_data}")
        return processed_posts
    except psycopg2.Error as db_err: print(f"DB Error listing posts: {db_err}"); raise HTTPException(status_code=500, detail="Database error listing posts")
    except Exception as e: print(f"❌ Error fetching posts: {e}"); traceback.print_exc(); raise HTTPException(status_code=500, detail="Error fetching posts")
    finally:
        if conn: conn.close()

@router.post("", status_code=status.HTTP_201_CREATED, response_model=schemas.PostDisplay)
async def create_post(
        current_user_id: int = Depends(auth.get_current_user),
        title: str = Form(...),
        content: str = Form(...),
        community_id: Optional[int] = Form(None),
        files: List[UploadFile] = File(default=[])
):
    conn = None; post_id = None; media_ids_created = []; minio_objects_created = []; comm_exists = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        actor_user = crud.get_user_by_id(cursor, current_user_id)
        actor_username = actor_user.get('username', 'Someone') if actor_user else 'Someone'

        if community_id is not None:
            comm_exists = crud.get_community_by_id(cursor, community_id)
            if not comm_exists: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Community {community_id} not found")

        post_id = crud.create_post_db(cursor, user_id=current_user_id, title=title, content=content)
        if post_id is None: raise HTTPException(status_code=500, detail="Post base creation failed")

        media_items_for_response_db = []
        if files:
            for file_upload in files:
                if file_upload and file_upload.filename:
                    object_name_prefix = f"media/posts/{post_id}"
                    upload_info = await utils.upload_file_to_minio(file_upload, object_name_prefix)
                    if upload_info:
                        minio_objects_created.append(upload_info['minio_object_name'])
                        media_id_db = crud.create_media_item(cursor, uploader_user_id=current_user_id, **upload_info)
                        if media_id_db:
                            media_ids_created.append(media_id_db)
                            crud.link_media_to_post(cursor, post_id, media_id_db)
                            media_item_for_resp = crud.get_media_item_by_id(cursor, media_id_db)
                            if media_item_for_resp: media_items_for_response_db.append(media_item_for_resp)
                        else: print(f"WARN: Failed media_item record for post {post_id}")
                    else: print(f"WARN: Failed upload for post {post_id}")

        if community_id is not None and comm_exists:
            crud.add_post_to_community_db(cursor, community_id, post_id)
            community_member_ids = crud.get_community_member_ids(cursor, community_id, limit=10000, offset=0)
            if community_member_ids:
                content_preview = f"New post in {comm_exists.get('name', 'your community')}: \"{title[:50]}...\""
                for member_id in community_member_ids:
                    if member_id != current_user_id:
                        crud.create_notification(cursor=cursor, recipient_user_id=member_id, actor_user_id=current_user_id, type='community_post', related_entity_type='post', related_entity_id=post_id, content_preview=content_preview)

        # Fetch complete data for response
        post_relational = crud.get_post_by_id(cursor, post_id)
        if not post_relational: raise HTTPException(status_code=500, detail="Could not retrieve created post after creation")

        created_post_data = dict(post_relational)
        created_post_data['author_name'] = actor_username
        author_avatar_media = crud.get_user_profile_picture_media(cursor, current_user_id)
        created_post_data['author_avatar_url'] = utils.get_minio_url(author_avatar_media.get('minio_object_name') if author_avatar_media else None)
        created_post_data['community_id'] = community_id
        created_post_data['community_name'] = comm_exists.get('name') if community_id and comm_exists else None
        counts = crud.get_post_counts(cursor, post_id)
        created_post_data.update(counts)
        created_post_data['media'] = [ {**item, 'url': utils.get_minio_url(item.get('minio_object_name'))} for item in media_items_for_response_db ]
        created_post_data['viewer_vote_type'] = None; created_post_data['viewer_has_favorited'] = False

        response_object = schemas.PostDisplay(**created_post_data)
        conn.commit()

        # Broadcast via Socket.IO if it's a community post
        if community_id is not None and sio: # sio is the AsyncServer instance
            target_room_key = f"community_{community_id}"
            # Prepare a payload that matches what frontend might expect for real-time 'new_post'
            # This could be the full PostDisplay or a summarized version.
            # For simplicity, let's use what we prepared for the HTTP response.
            # The schema of broadcast_payload must align with client-side expectations.
            broadcast_payload_dict = json.loads(response_object.model_dump_json(exclude_none=True))

            print(f"POSTS ROUTER: Attempting Socket.IO broadcast for new post {post_id} to room {target_room_key}")
            try:
                await sio.emit('new_post', broadcast_payload_dict, room=target_room_key)
                print(f"POSTS ROUTER: Broadcast successful for post {post_id}.")
            except Exception as sio_emit_err:
                print(f"POSTS ROUTER ERROR: Failed to broadcast new post via Socket.IO: {sio_emit_err}")

        return response_object

    except HTTPException as http_exc:
        if conn: conn.rollback();
        for obj in minio_objects_created: delete_from_minio(obj)
        raise http_exc
    except psycopg2.Error as db_err:
        if conn: conn.rollback();
        for obj in minio_objects_created: delete_from_minio(obj)
        print(f"❌ DB Error creating post: {db_err} (Code: {db_err.pgcode})")
        raise HTTPException(status_code=500, detail=f"Database error: {db_err.pgerror or 'Unknown DB Error'}")
    except Exception as e:
        if conn: conn.rollback();
        for obj in minio_objects_created: delete_from_minio(obj)
        print(f"❌ Unexpected Error creating post: {repr(e)}")
        traceback.print_exc();
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()


@router.delete("/{post_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_post(
        post_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    conn = None; media_to_delete: List[Dict[str, Any]] = []
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        post = crud.get_post_by_id(cursor, post_id)
        if not post: raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")
        if post["user_id"] != current_user_id: raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")
        media_to_delete = crud.get_media_items_for_post(cursor, post_id)
        deleted = crud.delete_post_db(cursor, post_id)
        if not deleted: conn.rollback(); raise HTTPException(status_code=404, detail="Post not found during deletion attempt")
        conn.commit()
        if media_to_delete:
            print(f"Attempting post-delete cleanup for {len(media_to_delete)} media items...")
            for media_item in media_to_delete:
                media_id_del = media_item.get("id"); minio_path_del = media_item.get("minio_object_name")
                if media_id_del: utils.delete_media_item_db_and_file(media_id_del, minio_path_del) # This helper is synchronous
                elif minio_path_del: utils.delete_from_minio(minio_path_del)
        return None
    except HTTPException as http_exc:
        if conn: conn.rollback(); raise http_exc
    except psycopg2.Error as e:
        if conn: conn.rollback(); print(f"❌ SQL Error deleting post {post_id}: {e}"); raise HTTPException(status_code=500, detail="Database error during deletion")
    except Exception as e:
        if conn: conn.rollback(); print(f"❌ Unexpected Error deleting post {post_id}: {e}"); raise HTTPException(status_code=500, detail="Could not delete post")
    finally:
        if conn: conn.close()


@router.post("/{post_id}/favorite", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def favorite_post(
        post_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        post_check = crud.get_post_by_id(cursor, post_id)
        if not post_check: raise HTTPException(status_code=404, detail="Post not found")
        success = crud.add_favorite_db(cursor, user_id=current_user_id, post_id=post_id, reply_id=None)
        conn.commit()
        counts = crud.get_post_counts(cursor, post_id)
        return {"message": "Post favorited successfully", "success": success, "new_counts": counts}
    except psycopg2.Error as e:
        if conn: conn.rollback(); print(f"❌ DB Error favoriting post {post_id}: {e}"); raise HTTPException(status_code=500, detail="Database error favoriting post")
    except HTTPException as http_exc:
        if conn: conn.rollback(); raise http_exc
    except Exception as e:
        if conn: conn.rollback(); print(f"❌ Error favoriting post {post_id}: {e}"); raise HTTPException(status_code=500, detail="Could not favorite post")
    finally:
        if conn: conn.close()

@router.delete("/{post_id}/favorite", status_code=status.HTTP_200_OK, response_model=Dict[str, Any])
async def unfavorite_post(
        post_id: int,
        current_user_id: int = Depends(auth.get_current_user)
):
    conn = None
    try:
        conn = get_db_connection(); cursor = conn.cursor()
        deleted = crud.remove_favorite_db(cursor, user_id=current_user_id, post_id=post_id, reply_id=None)
        conn.commit()
        counts = crud.get_post_counts(cursor, post_id)
        return {"message": "Post unfavorited successfully" if deleted else "Post was not favorited", "success": deleted, "new_counts": counts}
    except psycopg2.Error as e:
        if conn: conn.rollback(); print(f"❌ DB Error unfavoriting post {post_id}: {e}"); raise HTTPException(status_code=500, detail="Database error unfavoriting post")
    except Exception as e:
        if conn: conn.rollback(); print(f"❌ Error unfavoriting post {post_id}: {e}"); raise HTTPException(status_code=500, detail="Could not unfavorite post")
    finally:
        if conn: conn.close()