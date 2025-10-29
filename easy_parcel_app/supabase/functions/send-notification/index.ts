import { serve } from "std/http/server.ts"; 
import { createClient } from "supabase";   
import * as admin from "firebase-admin";

const FIREBASE_PRIVATE_KEY = Deno.env.get("-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCnpxTHEnNjWXc/\n0CMvcXq3bnFxQIiGutGJmqrkNknD/r89r0G+w4E6eGsiDnNMHFZEDXwyNLYuEtvY\nwgD25SIOZNuHTH8yivjvdvcZkQrshzu195XJLwTC/hd5QgWlYUvRvIpNqMFeaRou\nNoAFwgCh00CO4MFMRPOVbboSnJ+DuEXb2aICLceNrf8pDbbMfMDXMa64mERd0KF+\nA/KVk9dm8wmOpNlvty4uNKdN8zrCFHCtDStlHB8jvqKWR+QCp5FPjwI2pxsj8Z71\nvKF3axig2swAYj6Sdz3ATlb/umFfHnMXqontYGH/D1T0x1v18+EUIBlxe3rJH6UI\nMp0gMaqBAgMBAAECggEAElBPFbvvPOAOBbt/zHPx+s2muL9a6pTHxOdPWaSQhEd0\nrpFRdjw3BqMW2N6JO7wwtDhg478cU4Yd29y9bDr1cGsWC/6QOn4x2T6+mV1dux6+\nqA8GnrZzJ7XH7KgIo9swBBY7aWZQ0TZb9MZhT7+0f/jqqXDlzKYPkbgtxlCzoBi4\nhAsZ+uwuiRN4MY05mtiKxDT/du/47Q+IImUgu5AHkCzx5t9BAAOjqrHFHT79KTFR\n/CeOuR3bec0BwKmorifXbzAaXwmg8NF2pZ2kC0X7bAHYmiYAiTfBXlz7I3i9JziH\nxOUE6DMuK+YCIWCw5C6b+1tZiNC4ZcRVP8dVHvsPUQKBgQDn7cPhS/eHHiXjg9Ne\n3T7zzw0+UYK1XIrnB3N5MXIhUqgypphGbDK2wCjlssQfJ29IPjVHgxm/KDfed+5q\nZKUqKgYArm/rGZsVK2kO2NfKW34A2ED1ok84DSpX3KI+FTRUeEVQnznLWIPJhiXF\ndIendthgV/9xKOZjGuaw351ODQKBgQC5DYfuVvGT421QkXlPUGTT+mIr0aGGYsV0\nBSmgTuY0Flkj8DJXLdVdfhYPz5pxPadwr3DWKbiwmJBCHCdK7B/iFezKNSWhc9lU\nJhMA+bBaZMkDzKwT3RYWAHCA2u/HdejeT/tZFl0ALFBTkAA7nDlnx9uFBzz8jmzb\ngjZ4j2LlRQKBgB1Q9J2Z2KP/r5Jeq20mUjrHRUlHTFpYZEZnrrT3BxInPJOKc10T\neCWZjJHcUuYNOgfLtThg3fRHxSgdyMkyB56YyUF0yzjQd8XpQtJZno05m2fH7g4e\nghz3rQ6GGQv36jFzMm/KcKe/fIkQp92ZqTwFzbv/444OOXD1iYt5+IxRAoGAWqt9\nkdM51LtXQWW16Z27eX2yAkRZf03/70PkTG68LoNQs+Ip2DtV0tRHnQGca6XI19au\nU9DndGecLzg6LGSbjpwthDocMQphTvDE2PJ+bRv6vgjXu3fVLXyTox8i4zkrm1nX\nDqR9dus/hGIHKy31lpr/PSP5xslGHxui8tlWnH0CgYEAu4+eE0sXCKh/vqX9OVtU\nb36I+LFAyqpPygSM+dpXdle83CGG/1bBjHYWqWMYNzvl4HHmXcvhcixzltHAUmQr\nid6mpHhHC8bbWo6pEhjQAEidfXvV6SoN/U1tMdRwtsl55LoXHY8qgQPGJcme9Sg2\n6vOGXUR2H56YsINHFvpemNI=\n-----END PRIVATE KEY-----\n")!;
const FIREBASE_CLIENT_EMAIL = Deno.env.get("firebase-adminsdk-fbsvc@easy-parcel-d85dc.iam.gserviceaccount.com")!;
const FIREBASE_PROJECT_ID = Deno.env.get("easy-parcel-d85dc")!;

try {
  admin.initializeApp({
    credential: admin.credential.cert({
      privateKey: FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n"),
      clientEmail: FIREBASE_CLIENT_EMAIL,
      projectId: FIREBASE_PROJECT_ID,
    }),
  });
  console.log("Firebase Admin Initialized.");
} catch (e) {
  console.error("Firebase Admin Init Error:", e.message);
}

serve(async (req) => {
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const payload = await req.json();
    const newParcel = payload.record;

    console.log("New parcel received:", newParcel.id);

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("fcm_token")
      .eq("id", newParcel.studentId) 
      .single();

    if (profileError) throw profileError;
    if (!profile || !profile.fcm_token) {
      throw new Error(`No FCM token found for student ${newParcel.studentId}`);
    }

    const fcmToken = profile.fcm_token;
    console.log(`Found token: ${fcmToken}`);

    const message = {
      notification: {
        title: "Your Parcel Has Arrived! 📦",
        body:
          `Your parcel is ready for collection at Locker ${newParcel.lockerNumber}.`,
      },
      token: fcmToken,
    };

    console.log("Sending FCM message...");
    const response = await admin.messaging().send(message);
    console.log("Successfully sent message:", response);

    return new Response(JSON.stringify({ success: true, response }), {
      headers: { "Content-Type": "application/json" },
    });

  } catch (e) {
    console.error("Error:", e.message);
    return new Response(JSON.stringify({ success: false, error: e.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});