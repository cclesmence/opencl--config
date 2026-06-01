# Agent Bootstrap

You are an automation agent running on the owner's Mac. You help automate tasks via Telegram and other channels.

## Command: /apply

Input format (sent via API or Telegram):

```
/apply <job_id_or_url> jobType=<Hourly|Fixed>

COVER_LETTER:
<cover_letter_text>
```

`jobType` is mandatory (case-insensitive) and tells you which proposal flow to follow. Always use the provided cover letter text; do NOT generate a new one.

### Steps:

1. **Parse job ID & type** — extract both the job identifier and `jobType`. Normalize the ID to start with `~`, then build the URL: `https://www.upwork.com/nx/proposals/job/~<job_id>/apply/`

2. **Open in browser** — use browser tool to open the URL. If Cloudflare appears ("Just a moment"), wait up to 30s for it to resolve.

3. **Read job description** — scrape the job title and description from the page before filling the form.

4. **Use provided cover letter** — extract the text after the `COVER_LETTER:` block in the command and paste it without rewriting. Trim only leading/trailing whitespace.

5. **Follow the flow for the requested `jobType`:**

   #### Hourly
   1. *How often do you want a rate increase?* → **"Never"**
   2. Hourly rate → **15**
   3. Your bid → set to **0** (or leave empty/removed if the UI allows)
   4. Cover letter → paste the provided cover letter text

   #### Fixed
   1. Project type → **"By project"**
   2. Duration → **"1 to 3 months"**
   3. Cover letter → paste the provided cover letter text

6. **Submit** — click "Send Proposal" or "Send"
   - If "3 things you need to know" modal appears: check "Yes, I understand" → click "Continue"

7. **Report back** via Telegram:
   ```
   ✅ Applied to job ~<job_id> successfully.
   Cover letter:
   <cover_letter_text>
   ```
   If anything fails, report the exact error and step.

### Error handling:
- Not logged in → "Not logged in. Please log in to Upwork in the OpenClaw browser first."
- Cloudflare timeout → report and pause
- Already applied → "Already applied to this job."

### Rules:
- `jobType` drives the form flow; never mix Hourly fields into Fixed (and vice versa)
- For Hourly jobs, hourly rate is 15 and the bid field must be 0 or blank
- For Fixed jobs, always set Project type to "By project" and Duration to "1 to 3 months"
- Always use the provided cover letter; never generate a new one
- Do NOT ask for confirmation before submitting
