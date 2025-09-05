**ChatApp** 
A modern real-time messaging application built to connect people anytime, anywhere!

Here’s what you can do with ChatApp: 👇

💬 **Real-Time Messaging** – Send and receive messages instantly.

🔍 **Smart Search** – Find new users by their phone number and name to search existing user from your chat history.

📸 **Rich Media Support** – Share text, images, videos, GIFs, stickers, and emojis effortlessly.

🔐 **Secure Authentication** – Sign up & log in using Firebase Authentication.

👤 **Personalized Profiles** – Upload your profile picture, set your name & phone number

👥 **User Discovery** – Easily connect with new people or revisit existing conversations.
📱 **WhatsApp-like Features** – See user online/offline status, plus last message previews with timestamps for a familiar, intuitive chat flow.

⚡ **Seamless Experience** – Responsive and designed with Firebase at the core for reliable sync.

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 
🔥 Firestore Data Flow – ChatApp

ChatApp uses Firebase Firestore as the primary database to manage users, chats, and messages in real-time.

📂 Firestore Collections & Documents
1️⃣ Users Collection

Each registered user is stored under the users collection.

users (collection)
   └── userId (document)
        uid: "OW6DUBAFsbSuShlgGBxhV6V4Mjs2"
        email: "user@example.com"
        name: "Abhinav Sharma"
        phone: "+91XXXXXXXXXX"
        image_url: "https://..."
        timestamp: ...
        isOnline: true/false


✅ Created/Updated When:

On signup → only uid & email are stored.

On login → timestamp & isOnline are updated.

On profile completion → name, phone, image_url, etc. are added.

2️⃣ Chats Collection

Each chat is stored under the chats collection. A chat is uniquely identified by a chatId which is generated from both participants’ UIDs.

chats (collection)
   └── chatId_1 (document)   <-- Unique for user1 & user2
        participants: ["uid_1", "uid_2"]
        lastMessage: "Hey Rahul!"
        lastMessageTime: timestamp

        messages (subcollection)
           └── messageId_1
                senderId: "uid_1"
                type: "text"
                content: "Hey Rahul!"
                timestamp: ...
           └── messageId_2
                senderId: "uid_2"
                type: "image"
                content: "https://image_url..."
                timestamp: ...
           └── messageId_3
                senderId: "uid_1"
                type: "gif"
                content: "https://giphy.com/..."
                timestamp: ...


✅ Created/Updated When:

On starting a chat → chatId is created with participants array.

On sending a message → a new document is added under messages subcollection, and lastMessage + lastMessageTime are updated in the parent chat document.

Supports multiple message types: text, image, video, gif, sticker, etc.

⚡ Firestore Rules Overview
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    match /chats/{chatId} {
      allow read, write: if request.auth != null && request.auth.uid in resource.data.participants;
      
      match /messages/{messageId} {
        allow read, write: if request.auth != null && request.auth.uid in resource.parent.data.participants;
      }
    }
  }
}

🔄 Flow Summary

User Signup/Login → stores auth data inside users collection.

Profile Setup → updates user details (name, phone, image).

Start Chat → chats/chatId created with participants.

Send Message → stored inside messages subcollection, lastMessage updated.

Real-time Updates → Firestore listeners keep chat screen synced instantly.
