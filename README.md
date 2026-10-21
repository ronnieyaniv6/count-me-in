# Count Me In: setup guide

A wall of free local events. Anyone can browse. Signed-in people can post events, mark "Interested" or "I'm going", and report events. You can verify venues and remove anything.

It is a plain static site (`index.html`) plus a free Supabase database. Total setup time is about 20 minutes. Nothing here costs money at small scale.

## 1. Create the database (Supabase)

1. Sign up at https://supabase.com and click **New project**. Pick a name, a database password (save it somewhere), and the region closest to your users (London for the UK).
2. When the project is ready, open **SQL Editor** > **New query**.
3. Paste in the whole contents of `schema.sql` and press **Run**. You should see "Success". This creates the tables, the security rules and the feed.
4. Open **Project Settings** > **API**. Copy two values:
   - **Project URL**
   - **anon public** key (the long one labelled `anon` `public`)

The anon key is meant to be public. The security rules in `schema.sql` are what protect your data, so do not skip step 3.

## 2. Add your two values to the site

Open `index.html` in any text editor and find these two lines near the bottom:

```js
var SUPABASE_URL = 'PASTE_YOUR_PROJECT_URL_HERE';
var SUPABASE_ANON_KEY = 'PASTE_YOUR_ANON_PUBLIC_KEY_HERE';
```

Replace the text inside the quotes with your Project URL and anon key. Save.

## 3. Put it on Vercel

Easiest route, no command line:

1. Go to https://vercel.com, sign up, and click **Add New** > **Project**.
2. Choose **Deploy from a template / upload**, or push this folder to a GitHub repository and import it. For GitHub: create a repo, upload `index.html`, `schema.sql` and `README.md`, then import the repo in Vercel.
3. Leave all build settings empty (it is a static site) and click **Deploy**.

Vercel gives you an address like `count-me-in.vercel.app`.

## 4. Tell Supabase your site address

Sign-in links are emailed and must return to your site.

1. In Supabase open **Authentication** > **URL Configuration**.
2. Set **Site URL** to your Vercel address (for example `https://count-me-in.vercel.app`).
3. Under **Redirect URLs** add the same address followed by `/**`.

## 5. Make yourself an admin

Admins can mark venues Verified and delete any event.

1. Open your live site, click **Sign in**, and sign in with your email once.
2. In Supabase > **SQL Editor**, run this with your own email:

```sql
insert into public.admins (user_id)
select id from auth.users where email = 'you@example.com';
```

Refresh the site. Each event now shows **Mark verified** and **Delete**.

## Before you tell the public

- **Sign-in emails.** Supabase's built-in email sender only allows a few emails an hour, which is fine for testing but not for a launch. In **Authentication** > **SMTP Settings**, connect a free sender such as Resend or Brevo.
- **Spam.** Signing in with a real email stops most junk. If you see abuse, turn on CAPTCHA under **Authentication** > **Bot and Abuse Protection**.
- **Reports.** Three reports from different people hide an event from everyone except its poster and you. Reported events show a red report count to you, so check them from time to time.
- **Your own domain.** In Vercel, **Settings** > **Domains** lets you attach a name you have bought. Update the Supabase Site URL to match.
- **Rules of the wall.** The post form makes people confirm the event is free. Add your own wording about what is not allowed if you want more than that.

## How it fits together

- `index.html` is the whole website.
- `schema.sql` creates four tables (`events`, `rsvps`, `reports`, `admins`) and two functions (`feed`, `is_admin`).
- People can only change their own RSVPs and reports. Only the poster or an admin can delete an event. Only admins can set Verified.
