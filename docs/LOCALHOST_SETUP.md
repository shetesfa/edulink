# EduLink — Complete Localhost Setup (Step by Step)
# For Windows + XAMPP users — No experience needed

## STEP 0 — Download These 3 Programs First

| Program | Download Link | Notes |
|---------|--------------|-------|
| XAMPP   | https://www.apachefriends.org | Choose PHP 8.2 version |
| Node.js | https://nodejs.org | Choose LTS version |
| VS Code | https://code.visualstudio.com | Free code editor |

Install all 3 then restart your computer.

---

## STEP 1 — Extract EduLink Files

1. Take the `edulink-complete-v3.zip` file
2. Right-click → Extract All
3. Put the `edulink` folder inside: `C:\xampp\htdocs\`
4. Result: `C:\xampp\htdocs\edulink\`

---

## STEP 2 — Start XAMPP

1. Open XAMPP Control Panel (from Start Menu)
2. Click **START** next to **Apache**
3. Click **START** next to **MySQL**
4. Both should show green ✅

---

## STEP 3 — Create Database

1. Open your browser
2. Go to: `http://localhost/phpmyadmin`
3. Click **"New"** on the left sidebar
4. Type `edulink` as the database name
5. Click **Create**
6. Click on the `edulink` database in the left sidebar
7. Click **"Import"** tab at the top
8. Click **"Choose File"**
9. Find and select: `C:\xampp\htdocs\edulink\backend\database\migrations\001_create_all_tables.sql`
10. Scroll down → Click **"Import"**
11. You will see ✅ green success message

---

## STEP 4 — Set Up Backend

Open **VS Code** → File → Open Folder → select `C:\xampp\htdocs\edulink`

Click **Terminal → New Terminal** in VS Code

Type these commands one by one (press Enter after each):

```
cd backend
```

```
composer install
```
Wait 2-3 minutes for it to finish.

```
copy .env.example .env
```

```
php artisan key:generate
```

Now open `.env` file in VS Code (it's inside the `backend` folder).

Find these lines and make sure they look like this:
```
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=edulink
DB_USERNAME=root
DB_PASSWORD=
```
(DB_PASSWORD is empty — that's correct for XAMPP default)

Save the file (Ctrl+S).

Back in terminal, type:
```
php artisan storage:link
```

Then start Laravel:
```
php artisan serve
```

You will see:
```
INFO  Server running on [http://127.0.0.1:8000].
```
**Leave this terminal open.**

---

## STEP 5 — Set Up Real-time Server

Open a **second terminal** in VS Code:
Click the **+** icon next to the terminal tab at the bottom.

```
cd realtime
```

```
npm install
```

```
node server.js
```

You will see:
```
EduLink Socket.io server running on port 3001
```
**Leave this terminal open.**

---

## STEP 6 — Set Up Frontend

Open a **third terminal** (click + again).

```
cd frontend
```

```
npm install --legacy-peer-deps
```
Wait 2-3 minutes.

```
npm run dev
```

You will see:
```
  VITE v5.x.x  ready in xxx ms
  ➜  Local:   http://localhost:3000/
```

---

## STEP 7 — Open EduLink in Browser

Open your browser and go to:
```
http://localhost:3000
```

🎉 **EduLink is running!**

---

## STEP 8 — Add AI API Keys (Get Free AI Working)

Open `backend/.env` in VS Code and add your free API keys:

### Get Google Gemini Key (FREE — 1,500 req/day)
1. Go to: https://aistudio.google.com/app/apikey
2. Click "Create API Key"
3. Copy the key

In `.env` find the line:
```
GEMINI_API_KEY=
```
Change it to (paste your key after the =):
```
GEMINI_API_KEY=AIzaSyYOURKEYHERE
```

### Get Groq Key (FREE — 14,400 req/day — Fastest!)
1. Go to: https://console.groq.com
2. Sign up free → API Keys → Create API Key
3. Copy the key

```
GROQ_API_KEY=gsk_YOURKEYhere
```

### Get HuggingFace Key (FREE — Unlimited — Always works)
1. Go to: https://huggingface.co/settings/tokens
2. Create account → New Token → Copy it

```
HUGGINGFACE_API_KEY=hf_YOURKEYhere
```

After adding keys, go to the Laravel terminal and press **Ctrl+C** to stop, then:
```
php artisan serve
```

---

## STEP 9 — Create Your First Account

1. Go to `http://localhost:3000`
2. Click **"Get started"**
3. Choose **"School Admin"** role to create a school
4. Fill in your details
5. Click **"Create account"**

Then:
- Create a school
- Add teachers
- Teachers create classes
- Students join with class codes

---

## QUICK COMMANDS REFERENCE

Every time you want to start EduLink, open 3 terminals and run:

**Terminal 1 (Backend):**
```
cd C:\xampp\htdocs\edulink\backend
php artisan serve
```

**Terminal 2 (Real-time):**
```
cd C:\xampp\htdocs\edulink\realtime
node server.js
```

**Terminal 3 (Frontend):**
```
cd C:\xampp\htdocs\edulink\frontend
npm run dev
```

Then open: `http://localhost:3000`

---

## TROUBLESHOOTING

**"composer: command not found"**
→ Download Composer from https://getcomposer.org/Composer-Setup.exe
→ Install it, restart VS Code

**"npm: command not found"**
→ Download Node.js from https://nodejs.org (LTS)
→ Install, restart VS Code

**"php: command not found"**
→ XAMPP is not started. Open XAMPP → Start Apache + MySQL

**Page shows blank / error**
→ Check all 3 terminals are running (no red errors)
→ Make sure XAMPP MySQL is green

**"Connection refused" error**
→ Laravel is not running. Run: `php artisan serve` in backend folder

**Database error**
→ Check that MySQL is started in XAMPP
→ Check `.env` has `DB_USERNAME=root` and `DB_PASSWORD=` (empty)

**AI not working**
→ Add at least one API key to `.env`
→ Restart Laravel after editing `.env`
