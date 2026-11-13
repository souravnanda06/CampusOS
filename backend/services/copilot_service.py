"""
CampusOS AI Copilot Orchestrator.

Uses the official Google GenAI SDK (`google-genai`, Interactions API, `gemini-3.8-flash`)
with stateless role-scoped tool calling (`store=False`).
Gracefully falls back to a deterministic CampusOS Local Intent Engine when
`GEMINI_API_KEY` is unset or offline, executing the exact same RBAC-scoped DB tools.
"""

import base64
import datetime
import io
import json
import re

from config import Config
from models.user import User
from services.copilot_tools import (
    canonical_copilot_role,
    execute_tool,
    get_tools_for_role,
)

try:
    from google import genai
    from google.genai import types as genai_types
    GENAI_AVAILABLE = True
except ImportError:
    genai = None
    genai_types = None
    GENAI_AVAILABLE = False

try:
    from pypdf import PdfReader
    PYPDF_AVAILABLE = True
except ImportError:
    PdfReader = None
    PYPDF_AVAILABLE = False

LANGUAGE_NAMES = {
    'en': 'English',
    'hi': 'Hindi (हिन्दी)',
    'or': 'Odia (ଓଡ଼ିଆ)',
    'bn': 'Bengali (বাংলা)',
}


def _build_system_instruction(user: User, role: str, language: str, screen_context: str | None) -> str:
    lang_label = LANGUAGE_NAMES.get((language or 'en').lower(), 'English')
    today_iso = datetime.date.today().isoformat()

    role_rules = {
        'student': (
            "You are CampusOS Student Copilot. Help the student check attendance (and 75% safe-skip math), "
            "notices, fees, mess menu, request statuses, study practice questions (via format_study_practice_card), "
            "and draft leave requests, complaints, or official document requests (bonafide/NOC/etc.). "
            "Always call the appropriate tool before stating numbers, dates, or statuses. "
            "For write actions (leave, complaint, document request), ALWAYS call the matching draft_* tool so the user gets a confirmation card."
        ),
        'teacher': (
            "You are CampusOS Teacher Copilot — both an academic assistant and classroom co-author. "
            "You can: (1) create full structured exam papers, quizzes, assignments, viva banks, and rubrics "
            "(ALWAYS package generated assessments via format_assessment_paper with sections, marks, and an answer key), "
            "(2) create lecture/lesson plans (via format_lesson_plan), "
            "(3) inspect active/recent attendance sessions, cohort health, low-attendance students, and student check-in issues, "
            "(4) draft attendance sessions, class updates, targeted notices (teachers cannot target ALL students), or student device resets. "
            "Always use draft_* tools for write actions."
        ),
        'admin': (
            "You are CampusOS Admin Copilot for Deans and Campus Administrators. Provide concise, action-oriented campus intelligence: "
            "campus pulse, executive reports (via generate_executive_report), complaint SLA ageing (>48h), recurring clusters, "
            "pending student approvals (with draft_approve_student), fee/mess overview, campus notices, and complaint escalations. "
            "Always ground numbers in tool outputs and use draft_* tools for write actions."
        ),
    }

    profile_bits = [f"Name: {user.name}", f"Role: {role}"]
    if user.course:
        profile_bits.append(f"Course: {user.course}")
    if user.branch:
        profile_bits.append(f"Branch: {user.branch}")
    if user.year:
        profile_bits.append(f"Year: {user.year}")
    if user.registration_number:
        profile_bits.append(f"RegNo: {user.registration_number}")
    if screen_context:
        profile_bits.append(f"CurrentScreen: {screen_context}")

    return (
        f"{role_rules.get(role, '')}\n"
        f"Signed-in user: {', '.join(profile_bits)}.\n"
        f"Today's date: {today_iso}.\n"
        f"Respond in {lang_label}. Keep replies concise, structured, and factual. "
        "Never invent IDs, fees, attendance counts, or notices; if a tool returns empty data, say so clearly."
    )


def get_role_suggestions(role: str, language: str = 'en') -> list[dict]:
    if role == 'student':
        return [
            {'label': '75% Attendance Check', 'prompt': 'Check my attendance and tell me how many classes I can skip or need for 75%'},
            {'label': 'Practice Quiz Prep', 'prompt': 'Create 5 practice exam questions on DBMS Normalization with short answers'},
            {'label': 'Request Bonafide', 'prompt': 'Draft a Bonafide Certificate request for internship verification'},
            {'label': "Today's Mess Menu", 'prompt': "What is on today's mess menu?"},
            {'label': 'Latest Notices', 'prompt': 'Summarize my latest campus notices'},
            {'label': 'Apply Weekend Leave', 'prompt': 'Draft a home visit leave request for tomorrow to day after tomorrow for family function'},
        ]
    if role == 'teacher':
        return [
            {'label': 'Create Exam Paper', 'prompt': 'Create a 30-mark mid-sem exam paper for DBMS (Units 1-3) with 5 MCQs, 3 short questions, 2 long questions, and answer key'},
            {'label': '50-Min Lesson Plan', 'prompt': 'Create a 50-minute lesson plan on Operating Systems Deadlocks with examples and exit quiz'},
            {'label': 'Low Attendance (<75%)', 'prompt': 'Which students are below 75% attendance right now?'},
            {'label': 'Class Cohort Health', 'prompt': 'Show overall class cohort attendance health breakdown'},
            {'label': 'Start Lecture Session', 'prompt': 'Draft an attendance session for Data Structures in Room 204'},
            {'label': 'Post Class Update', 'prompt': 'Draft a class announcement for CS301 Data Structures that assignment 3 is due Friday'},
        ]
    if role == 'admin':
        return [
            {'label': 'Executive Report', 'prompt': 'Generate today’s executive campus briefing report'},
            {'label': 'Campus Pulse Briefing', 'prompt': 'Give me today’s campus pulse briefing'},
            {'label': 'Ageing & Recurring Issues', 'prompt': 'Show complaints ageing over 48 hours and recurring clusters'},
            {'label': 'Pending Student Approvals', 'prompt': 'List pending student registration approvals'},
            {'label': 'Fees & Mess Overview', 'prompt': 'Show campus fee collection and mess rating overview'},
            {'label': 'Draft Campus Notice', 'prompt': 'Draft an urgent notice for all students about mid-semester registration verification'},
        ]
    return []


def _extract_cards_and_actions(tool_name: str, tool_result: dict, cards: list, pending_actions: list):
    if not isinstance(tool_result, dict):
        return

    if 'pendingAction' in tool_result and isinstance(tool_result['pendingAction'], dict):
        pending_actions.append(tool_result['pendingAction'])
        return

    if 'documentCard' in tool_result and isinstance(tool_result['documentCard'], dict):
        cards.append(tool_result['documentCard'])
        if 'pulse' not in tool_result:
            return

    if tool_name == 'get_class_cohort_health':
        cards.append({
            'type': 'metrics',
            'title': 'Cohort Attendance Health',
            'items': [
                {'label': 'Class Avg', 'value': f"{tool_result.get('averagePercentage', 0)}%"},
                {'label': 'Good (>=85%)', 'value': str(tool_result.get('good', 0))},
                {'label': 'Borderline', 'value': str(tool_result.get('borderline', 0))},
                {'label': 'At Risk (<75%)', 'value': str(tool_result.get('atRisk', 0))},
            ],
        })

    if tool_name == 'get_my_attendance_summary':
        cards.append({
            'type': 'metrics',
            'title': 'Attendance Snapshot',
            'items': [
                {'label': 'Overall', 'value': f"{tool_result.get('overallPercentage', 0)}%"},
                {'label': 'Attended', 'value': f"{tool_result.get('attended', 0)}/{tool_result.get('totalSessions', 0)}"},
                {
                    'label': 'Safe to Skip' if tool_result.get('safeToSkipClasses', 0) > 0 else 'Needed for 75%',
                    'value': str(
                        tool_result.get('safeToSkipClasses', 0)
                        if tool_result.get('safeToSkipClasses', 0) > 0
                        else tool_result.get('classesNeededFor75', 0)
                    ),
                },
            ],
        })
    elif tool_name == 'get_my_fees':
        cards.append({
            'type': 'metrics',
            'title': 'Fee Summary',
            'items': [
                {'label': 'Total Due', 'value': f"₹{tool_result.get('totalDue', 0)}"},
                {'label': 'Paid', 'value': f"₹{tool_result.get('totalPaid', 0)}"},
                {'label': 'Overdue', 'value': 'Yes' if tool_result.get('hasOverdue') else 'No'},
            ],
        })
    elif tool_name == 'get_campus_pulse':
        cards.append({
            'type': 'metrics',
            'title': 'Campus Command Pulse',
            'items': [
                {'label': 'Active Sessions', 'value': str(tool_result.get('activeAttendanceSessions', 0))},
                {'label': 'Pending Complaints', 'value': str(tool_result.get('pendingComplaints', 0))},
                {'label': 'Ageing (>48h)', 'value': str(tool_result.get('ageingComplaintsOver48h', 0))},
                {'label': 'Student Approvals', 'value': str(tool_result.get('pendingStudentApprovals', 0))},
            ],
        })
    elif tool_name == 'get_low_attendance_students':
        students = tool_result.get('students') or []
        if students:
            cards.append({
                'type': 'list',
                'title': f"Below {tool_result.get('threshold', 75)}% ({tool_result.get('count', len(students))})",
                'rows': [
                    {
                        'title': s.get('name', 'Student'),
                        'subtitle': f"{s.get('registrationNumber') or ''} · {s.get('branch') or ''} {s.get('year') or ''}".strip(' ·'),
                        'badge': f"{s.get('percentage', 0)}%",
                    }
                    for s in students[:5]
                ],
            })
    elif tool_name == 'get_ageing_and_recurring_complaints':
        clusters = tool_result.get('recurringClusters') or []
        ageing = tool_result.get('ageingComplaints') or []
        if ageing:
            cards.append({
                'type': 'list',
                'title': f"Ageing Complaints ({tool_result.get('ageingCount', len(ageing))})",
                'rows': [
                    {
                        'title': c.get('title', 'Complaint'),
                        'subtitle': f"{c.get('category', '')} · {c.get('location', '')}",
                        'badge': f"{c.get('ageHours', 0)}h",
                    }
                    for c in ageing[:5]
                ],
            })
        elif clusters:
            cards.append({
                'type': 'list',
                'title': f"Recurring Clusters ({len(clusters)})",
                'rows': [
                    {
                        'title': f"{cl.get('category', '')} at {cl.get('location', '')}",
                        'subtitle': f"Escalation: {cl.get('escalationTier', 'NORMAL')}",
                        'badge': f"{cl.get('complaintCount', 0)}x",
                    }
                    for cl in clusters[:5]
                ],
            })


def _extract_dates_hint(text: str) -> tuple[str, str]:
    today = datetime.date.today()
    iso_matches = re.findall(r'\b(20\d{2}-\d{2}-\d{2})\b', text)
    if len(iso_matches) >= 2:
        return iso_matches[0], iso_matches[1]
    if len(iso_matches) == 1:
        return iso_matches[0], iso_matches[0]
    lower = text.lower()
    if 'weekend' in lower:
        # Next Saturday to Sunday
        days_until_sat = (5 - today.weekday()) % 7
        if days_until_sat == 0:
            days_until_sat = 7
        sat = today + datetime.timedelta(days=days_until_sat)
        return sat.isoformat(), (sat + datetime.timedelta(days=1)).isoformat()
    if 'tomorrow' in lower:
        tmr = today + datetime.timedelta(days=1)
        end = tmr + datetime.timedelta(days=1) if 'day after' in lower else tmr
        return tmr.isoformat(), end.isoformat()
    return (today + datetime.timedelta(days=1)).isoformat(), (today + datetime.timedelta(days=1)).isoformat()


def _extract_uploaded_topics(uploaded_texts: list[str], attachment_names: list[str] | None = None) -> tuple[str, list[str]]:
    """Extracts a clean title/topic and key non-empty lines from uploaded notes."""
    combined = "\n".join(uploaded_texts or []).strip()
    lines = []
    for raw in combined.splitlines():
        s = raw.strip()
        if not s or s.startswith('[Uploaded '):
            continue
        if len(s) >= 4:
            lines.append(s)
    if lines:
        title = lines[0][:60]
    elif attachment_names:
        clean = re.sub(r'\.[a-zA-Z0-9]+$', '', attachment_names[0])
        title = clean.replace('_', ' ').replace('-', ' ').strip()
    else:
        title = 'Uploaded Notes'
    return title, lines[:12]


def _run_local_fallback(
    user: User,
    role: str,
    message: str,
    uploaded_texts: list[str] | None = None,
    attachment_names: list[str] | None = None,
    fallback_reason: str | None = None,
) -> dict:
    """
    Deterministic role-scoped intent router when GEMINI_API_KEY is not configured or unavailable.
    Executes the exact same DB tools and uses extracted text from uploaded PDF/text notes.
    """
    q = (message or '').strip()
    ql = q.lower()
    cards = []
    pending_actions = []
    tools_used = []
    reply_parts = []
    notes_list = [t for t in (uploaded_texts or []) if t and t.strip()]
    has_notes = len(notes_list) > 0 or (attachment_names and len(attachment_names) > 0)
    doc_topic, doc_lines = _extract_uploaded_topics(notes_list, attachment_names)

    def call(name: str, args: dict | None = None) -> dict:
        tools_used.append(name)
        res = execute_tool(role, user, name, args or {})
        _extract_cards_and_actions(name, res, cards, pending_actions)
        return res

    if role == 'student':
        if any(k in ql for k in ('leave', 'home visit', 'outing', 'absent', 'medical leave')):
            sd, ed = _extract_dates_hint(q)
            ltype = 'MEDICAL' if 'medical' in ql else ('OUTING' if 'outing' in ql else 'HOME_VISIT')
            call('draft_leave_request', {
                'leave_type': ltype,
                'start_date': sd,
                'end_date': ed,
                'reason': q[:180],
            })
            reply_parts.append(
                f"I've drafted a **{ltype}** leave request from **{sd}** to **{ed}**. Review the details below and tap **Confirm & Execute** to submit it."
            )
        elif any(k in ql for k in ('complaint', 'broken', 'leak', 'fan', 'wifi', 'report issue', 'not working', 'fix')):
            cat = 'ELECTRICAL' if any(w in ql for w in ('fan', 'light', 'power', 'ac', 'switch')) else (
                'PLUMBING' if any(w in ql for w in ('water', 'leak', 'tap', 'pipe', 'bathroom')) else (
                    'INTERNET' if any(w in ql for w in ('wifi', 'internet', 'network')) else 'MAINTENANCE'
                )
            )
            loc_match = re.search(r'(?:in|at)\s+([A-Za-z0-9\-\s]{3,35})', q, re.IGNORECASE)
            loc = loc_match.group(1).strip() if loc_match else 'Hostel / Campus'
            call('draft_complaint', {
                'category': cat,
                'title': q[:80],
                'description': q,
                'location': loc,
                'priority': 'HIGH' if 'urgent' in ql else 'MEDIUM',
            })
            reply_parts.append(
                f"I've drafted a **{cat}** complaint for **{loc}**. Confirm below to file it and generate your verification PIN."
            )
        elif any(k in ql for k in ('mess', 'menu', 'food', 'dinner', 'lunch', 'breakfast')):
            res = call('get_today_mess_menu')
            if res.get('found'):
                meals_txt = "\n".join(
                    f"- **{m['mealType']}**: {', '.join(m['items']) or m['title']}"
                    for m in res.get('meals', [])
                )
                reply_parts.append(f"Here is the published mess menu for **{res['menuDate']}**:\n{meals_txt}")
            else:
                reply_parts.append("No published mess menu is available right now.")
        elif any(k in ql for k in ('fee', 'due', 'payment', 'receipt')):
            res = call('get_my_fees')
            reply_parts.append(
                f"Your total fee due is **₹{res['totalDue']}** (Paid: ₹{res['totalPaid']} across {len(res['records'])} record(s))."
            )
        elif any(k in ql for k in ('notice', 'circular', 'exam', 'announcement')):
            res = call('get_my_notices')
            if res['count'] == 0:
                reply_parts.append("There are no active notices targeted to you right now.")
            else:
                lines = "\n".join(f"- **[{n['priority']}] {n['title']}**: {n['body'][:110]}" for n in res['notices'][:4])
                reply_parts.append(f"Here are your latest **{res['count']}** notice(s):\n{lines}")
        elif any(k in ql for k in ('bonafide', 'noc', 'certificate', 'conduct certificate', 'hostel residence')):
            dtype = 'INTERNSHIP_NOC' if 'noc' in ql or 'internship' in ql else (
                'HOSTEL_RESIDENCE_CERTIFICATE' if 'hostel' in ql else (
                    'CONDUCT_CERTIFICATE' if 'conduct' in ql else 'BONAFIDE_CERTIFICATE'
                )
            )
            call('draft_document_request', {
                'document_type': dtype,
                'purpose': q[:180],
            })
            reply_parts.append(
                "I've drafted your official certificate request. Review the details and tap **Confirm & Execute** to submit."
            )
        elif any(k in ql for k in ('practice', 'quiz', 'viva', 'study', 'question')) or (has_notes and role == 'student'):
            if has_notes and doc_lines:
                qs = "\n".join(
                    f"{idx + 1}. Explain and review: {line[:120]}"
                    for idx, line in enumerate(doc_lines[:5])
                )
                ans = "\n".join(
                    f"{idx + 1}. Key point from notes: {line[:140]}"
                    for idx, line in enumerate(doc_lines[:5])
                )
                call('format_study_practice_card', {
                    'topic': doc_topic,
                    'subject': user.branch or 'Uploaded Notes',
                    'difficulty': 'Medium',
                    'questions_markdown': qs,
                    'answers_markdown': ans,
                })
                reply_parts.append(f"Created practice questions from **{doc_topic}** (local text mode).")
            else:
                call('format_study_practice_card', {
                    'topic': q[:60],
                    'subject': user.branch or 'Core Subject',
                    'difficulty': 'Medium',
                    'questions_markdown': (
                        "1. Define the core concept and explain why it matters in practice.\n"
                        "2. Compare two common approaches and state their trade-offs.\n"
                        "3. Walk through a concrete example step-by-step.\n"
                        "4. Identify two common edge cases or failure modes.\n"
                        "5. Write a short 3-line viva summary."
                    ),
                    'answers_markdown': "Use your class notes and verify each step against the worked examples.",
                })
                reply_parts.append("Here is a structured practice set you can copy and review:")
        elif any(k in ql for k in ('request', 'status', 'ticket', 'document')):
            res = call('get_my_requests_status')
            reply_parts.append(
                f"You have **{len(res['leaves'])}** recent leave request(s), **{len(res['complaints'])}** complaint(s), and **{len(res['documents'])}** document request(s)."
            )
        else:
            res = call('get_my_attendance_summary')
            pct = res['overallPercentage']
            if res['totalSessions'] == 0:
                reply_parts.append("No attendance sessions have been recorded for your class yet.")
            elif pct >= 75.0:
                reply_parts.append(
                    f"Your overall attendance is **{pct}%** ({res['attended']}/{res['totalSessions']}). You can safely miss up to **{res['safeToSkipClasses']}** class(es) and remain at or above 75%."
                )
            else:
                reply_parts.append(
                    f"Your overall attendance is **{pct}%** ({res['attended']}/{res['totalSessions']}). You need **{res['classesNeededFor75']}** consecutive class(es) to reach 75%."
                )

    elif role == 'teacher':
        if has_notes and any(k in ql for k in ('notice', 'circular', 'announcement', 'update', 'share', 'publish')):
            summary_body = " ".join(doc_lines[:6])[:400] if doc_lines else q
            call('draft_targeted_notice', {
                'title': doc_topic[:100],
                'body': summary_body,
                'target_type': 'BRANCH',
                'target_value': user.branch or 'CSE',
                'category': 'ACADEMIC',
            })
            reply_parts.append(f"I've drafted a notice from your uploaded file (**{doc_topic}**) for **{user.branch or 'CSE'}**. Confirm below to publish.")
        elif any(k in ql for k in ('exam', 'paper', 'quiz', 'assessment', 'test', 'question bank', 'mid-sem', 'midsem', 'assignment')):
            if has_notes and doc_lines:
                subj = doc_topic
                sec_a = "\n".join(
                    f"{i + 1}. Briefly explain: \"{line[:110]}\" [2]"
                    for i, line in enumerate(doc_lines[:5])
                )
                sec_b = "\n".join(
                    f"{i + 6}. Discuss in detail with examples: \"{line[:120]}\" [10]"
                    for i, line in enumerate(doc_lines[5:7] or doc_lines[:2])
                )
                paper_md = f"Source Material: {doc_topic}\n\nSection A — Short Questions (10 Marks)\n{sec_a}\n\nSection B — Long / Analytical (20 Marks)\n{sec_b}"
                ans_md = "Reference points extracted from uploaded file:\n" + "\n".join(f"- {l[:140]}" for l in doc_lines[:7])
            elif has_notes and (attachment_names or doc_topic != 'Uploaded Notes'):
                subj = doc_topic
                paper_md = (
                    f"Subject / Topic: {subj}\n\n"
                    f"Section A — Core Checks & Understanding (10 Marks)\n"
                    f"1. Explain the primary objectives and key requirements of {subj}. [2]\n"
                    f"2. State two essential guidelines or deadlines associated with {subj}. [2]\n"
                    f"3. Differentiate between acceptable and incomplete submissions for {subj}. [2]\n"
                    f"4. Outline the verification and assessment workflow for {subj}. [2]\n"
                    f"5. What common issues should students avoid regarding {subj}? [2]\n\n"
                    f"Section B — Evaluation Rubric & Viva Assessment (10 Marks)\n"
                    f"6. Provide a detailed rubric and step-by-step viva voce evaluation guide for {subj}. [10]"
                )
                ans_md = (
                    f"Assessment Key for {subj}:\n"
                    f"• Section A: 2 marks per question for accurate terminology and verification compliance.\n"
                    f"• Section B: 4 marks submission completeness, 3 marks viva explanation, 3 marks documentation accuracy."
                )
            else:
                subj_match = re.search(r'(?:for|on|in|about)\s+([A-Za-z0-9\s&\(\)-]{2,45})', q, re.IGNORECASE)
                raw_subj = subj_match.group(1).strip() if subj_match else ''
                clean_subj = re.sub(r'\b(with\s+examples|and\s+exit\s+quiz|with\s+quiz|for\s+class)\b.*', '', raw_subj, flags=re.IGNORECASE).strip()
                subj = clean_subj or (user.branch or 'Computer Science')
                paper_md = (
                    f"Section A — Objective / Short Check (10 Marks)\n"
                    f"1. Define the foundational principles of {subj}. [2]\n"
                    f"2. Identify key trade-offs and constraints in {subj}. [2]\n"
                    f"3. State one real-world application and justify why it works. [2]\n"
                    f"4. Distinguish between the two primary models in {subj}. [2]\n"
                    f"5. Spot and correct a common misconception in {subj}. [2]\n\n"
                    f"Section B — Analytical & Problem Solving (20 Marks)\n"
                    f"6. Analyze a realistic scenario applying {subj} concepts step-by-step. [10]\n"
                    f"7. Design a complete solution or proof for a core problem in {subj}. [10]"
                )
                ans_md = "Section A: 2 marks each for exact definitions and justification.\nSection B: 4 marks methodology, 4 marks accuracy, 2 marks edge cases."

            call('format_assessment_paper', {
                'title': f"{subj} Assessment Paper",
                'subject': subj,
                'assessment_type': 'QUIZ' if 'quiz' in ql else ('ASSIGNMENT' if 'assignment' in ql else 'MID_SEM_EXAM'),
                'total_marks': 20 if 'quiz' in ql else 30,
                'duration_minutes': 30 if 'quiz' in ql else 60,
                'difficulty': 'Balanced',
                'paper_markdown': paper_md,
                'answer_key_markdown': ans_md,
            })
            reply_parts.append(f"I've generated an assessment paper for **{subj}**. You can copy it directly from the card below.")
        elif has_notes:
            # Teacher uploaded a file and asked to summarize / extract dates / explain / do anything else
            if doc_lines:
                bullets = "\n".join(f"- {l[:180]}" for l in doc_lines[:8])
                cards.append({
                    'type': 'document',
                    'title': f"Extracted Summary: {doc_topic}",
                    'subtitle': 'Uploaded File Content',
                    'badges': ['FILE SUMMARY', f"{len(doc_lines)} Key Lines"],
                    'content': bullets,
                    'answerKey': None,
                })
                reply_parts.append(f"Here is what I extracted from **{doc_topic}**:\n{bullets}")
            else:
                reply_parts.append(
                    f"Received **{doc_topic}**. The file appears to be a scanned document or image without embedded text layers. You can ask me to draft a notice or quiz on this topic directly."
                )
        elif any(k in ql for k in ('lesson plan', 'lecture plan', 'teach', 'syllabus plan')):
            topic_match = re.search(r'(?:on|for|about)\s+([A-Za-z0-9\s&\(\)-]{2,50})', q, re.IGNORECASE)
            raw_topic = topic_match.group(1).strip() if topic_match else ''
            clean_topic = re.sub(r'\b(with\s+examples|and\s+exit\s+quiz|with\s+quiz|for\s+class)\b.*', '', raw_topic, flags=re.IGNORECASE).strip()
            topic = clean_topic or (doc_topic if has_notes else (user.branch or 'Course Lecture'))
            call('format_lesson_plan', {
                'topic': topic,
                'subject': user.branch or 'Core Subject',
                'duration_minutes': 50,
                'plan_markdown': (
                    f"• 00-05 min: Context Hook & Real-World Analogy for {topic}\n"
                    f"• 05-20 min: Core Architectural & Theoretical Foundations of {topic}\n"
                    f"• 20-35 min: Step-by-Step Worked Problem & Practical Demonstration\n"
                    f"• 35-45 min: Guided Student Pair Activity & Edge-Case Analysis\n"
                    f"• 45-50 min: 2-Question Exit Quiz Ticket & Next Session Preview"
                ),
            })
            reply_parts.append(f"Here is a structured 50-minute lesson plan for **{topic}** ready to copy:")
        elif any(k in ql for k in ('cohort', 'health', 'distribution', 'class average')):
            res = call('get_class_cohort_health', {'branch': user.branch, 'year': user.year})
            reply_parts.append(
                f"Cohort Health: **{res['averagePercentage']}%** average across {res['evaluatedStudents']} evaluated student(s) "
                f"({res['good']} Good, {res['borderline']} Borderline, {res['atRisk']} At Risk)."
            )
        elif 'reset' in ql and 'device' in ql:
            tokens = [t for t in q.split() if len(t) >= 3]
            lookup = tokens[-1] if tokens else ''
            res = call('draft_reset_student_device', {'student_query': lookup, 'reason': q[:120]})
            if res.get('pendingAction'):
                reply_parts.append("I've prepared a device binding reset confirmation card below.")
            else:
                reply_parts.append(res.get('message', 'Specify a student name or registration number to reset their device.'))
        elif any(k in ql for k in ('start session', 'create session', 'take attendance', 'launch', 'draft an attendance')):
            subj_match = re.search(r'(?:for|subject)\s+([A-Za-z0-9\s&]{2,40})', q, re.IGNORECASE)
            subj = subj_match.group(1).strip() if subj_match else 'Data Structures'
            loc_match = re.search(r'(?:in|room)\s+([A-Za-z0-9\-\s]{2,25})', q, re.IGNORECASE)
            loc = loc_match.group(1).strip() if loc_match else 'Room 204'
            call('draft_attendance_session', {
                'subject': subj,
                'branch': user.branch or 'CSE',
                'year': user.year or '3rd',
                'location': loc,
            })
            reply_parts.append(
                f"I've prepared a live attendance session for **{subj}** in **{loc}**. Confirm below to start broadcasting."
            )
        elif any(k in ql for k in ('class update', 'announcement', 'cancel', 'reschedule', 'assignment')):
            call('draft_class_update', {
                'course_code': 'CS301',
                'course_name': 'Course Update',
                'update_type': 'CANCELLED' if 'cancel' in ql else ('RESCHEDULED' if 'reschedule' in ql else 'ANNOUNCEMENT'),
                'message': q,
                'affected_branch': user.branch or 'CSE',
                'affected_year': user.year,
            })
            reply_parts.append("I've drafted the class update. Review and tap **Confirm & Execute** to notify students.")
        elif 'notice' in ql or 'circular' in ql:
            call('draft_targeted_notice', {
                'title': 'Faculty Academic Notice',
                'body': q,
                'target_type': 'BRANCH',
                'target_value': user.branch or 'CSE',
            })
            reply_parts.append(f"I've drafted a targeted notice for **{user.branch or 'CSE'}**. Confirm below to publish.")
        elif any(k in ql for k in ('below', 'low', 'risk', '75%', 'shortage')):
            res = call('get_low_attendance_students', {'threshold': 75.0})
            if res['count'] == 0:
                reply_parts.append("Great news — no students are currently below 75% attendance.")
            else:
                reply_parts.append(f"Found **{res['count']}** student(s) below 75% attendance. See the breakdown card below.")
        elif any(k in ql for k in ('student', 'check', 'roll', 'device', 'why')):
            tokens = [t for t in q.split() if len(t) >= 3]
            lookup = tokens[-1] if tokens else ''
            res = call('check_student_attendance_issue', {'query': lookup})
            if res.get('found'):
                st = res['student']
                reply_parts.append(
                    f"**{st['name']}** ({st.get('registrationNumber') or 'N/A'}): Approval `{st['approvalStatus']}`, Device bound: `{st['hasBoundDevice']}`, Face enrolled: `{st['faceEnrolled']}`."
                )
            else:
                reply_parts.append(res.get('message', 'Specify a student name or registration number to inspect.'))
        else:
            res = call('get_teacher_sessions_summary')
            reply_parts.append(
                f"You have **{len(res['activeSessions'])}** active session(s), **{len(res['recentSessions'])}** recent session(s), and **{len(res['savedClasses'])}** saved class preset(s)."
            )

    elif role == 'admin':
        if any(k in ql for k in ('executive', 'report', 'briefing report')):
            res = call('generate_executive_report')
            p = res.get('pulse', {})
            reply_parts.append(
                f"Generated today's **Executive Campus Report** ({p.get('totalStudents', 0)} students, {p.get('ageingComplaintsOver48h', 0)} >48h ageing complaints). You can copy the full report below."
            )
        elif 'approve' in ql and 'student' in ql:
            tokens = [t for t in q.split() if len(t) >= 3 and t.lower() not in ('approve', 'student', 'pending', 'registration')]
            lookup = tokens[-1] if tokens else ''
            res = call('draft_approve_student', {'student_query': lookup})
            if res.get('pendingAction'):
                reply_parts.append("I've prepared the student registration approval confirmation card below.")
            else:
                reply_parts.append(res.get('message', 'No pending student registration found.'))
        elif any(k in ql for k in ('notice', 'circular', 'draft', 'broadcast', 'publish')):
            prio = 'URGENT' if 'urgent' in ql else ('HIGH' if 'important' in ql else 'NORMAL')
            call('draft_campus_notice', {
                'title': 'Campus Administrative Circular',
                'body': q,
                'target_type': 'ALL',
                'priority': prio,
            })
            reply_parts.append("I've drafted the campus notice. Review the target audience and tap **Confirm & Execute** to publish.")
        elif any(k in ql for k in ('ageing', 'aging', 'recurring', 'cluster', 'sla', 'complaint', '48')):
            res = call('get_ageing_and_recurring_complaints')
            reply_parts.append(
                f"There are **{res['ageingCount']}** ageing complaint(s) (>48h) and **{res['recurringClusterCount']}** recurring issue cluster(s)."
            )
        elif any(k in ql for k in ('approval', 'registration', 'pending student')):
            res = call('get_pending_student_approvals')
            if res['count'] == 0:
                reply_parts.append("No student registrations are currently awaiting approval.")
            else:
                names = ", ".join(s['name'] for s in res['students'][:5])
                reply_parts.append(f"**{res['count']}** student registration(s) pending approval: {names}.")
        elif any(k in ql for k in ('fee', 'mess', 'rating', 'collection')):
            res = call('get_fee_and_mess_overview')
            reply_parts.append(
                f"Fee collected: **₹{res['feeTotalCollected']}** / ₹{res['feeTotalBilled']} (Outstanding: **₹{res['feeTotalOutstanding']}**, Overdue records: {res['overdueRecords']}). Mess average rating: **{res['messAverageRating'] or 'N/A'}**."
            )
        else:
            res = call('get_campus_pulse')
            reply_parts.append(
                f"**Campus Pulse:** {res['totalStudents']} students, {res['activeAttendanceSessions']} active session(s), "
                f"{res['pendingComplaints']} pending complaints ({res['ageingComplaintsOver48h']} ageing >48h), "
                f"{res['pendingStudentApprovals']} pending registration approvals, and {res['pendingLeaveRequests']} pending leave requests."
            )

    resp_payload = {
        'reply': "\n\n".join(reply_parts) or "I'm ready to help with your CampusOS tasks.",
        'role': role,
        'mode': 'local_assist',
        'cards': cards,
        'pendingActions': pending_actions,
        'toolsUsed': tools_used,
        'suggestedPrompts': get_role_suggestions(role),
    }
    if fallback_reason:
        resp_payload['fallbackReason'] = fallback_reason
    return resp_payload


def _extract_pdf_text_pure_python(raw_bytes: bytes) -> str:
    """Extracts text streams from PDF without external dependencies using standard zlib."""
    if not raw_bytes:
        return ''
    try:
        import zlib
        stream_pattern = re.compile(b'stream[\r\n]+(.*?)[\r\n]+endstream', re.DOTALL)
        text_chunks = []
        for match in stream_pattern.finditer(raw_bytes):
            stream_data = match.group(1)
            decompressed = None
            try:
                decompressed = zlib.decompress(stream_data)
            except Exception:
                try:
                    decompressed = zlib.decompress(stream_data, -zlib.MAX_WBITS)
                except Exception:
                    decompressed = stream_data
            if decompressed:
                tj_matches = re.findall(rb'\(([^\)\\]*(?:\\.[^\)\\]*)*)\)\s*(?:Tj|\')', decompressed)
                for tj in tj_matches:
                    try:
                        s = tj.decode('utf-8', errors='ignore').strip()
                        if s and len(s) > 1:
                            text_chunks.append(s)
                    except Exception:
                        pass
                array_matches = re.findall(rb'\[(.*?)\]\s*TJ', decompressed, re.DOTALL)
                for arr in array_matches:
                    parts = re.findall(rb'\(([^\)\\]*(?:\\.[^\)\\]*)*)\)', arr)
                    for p in parts:
                        try:
                            s = p.decode('utf-8', errors='ignore').strip()
                            if s and len(s) > 1:
                                text_chunks.append(s)
                        except Exception:
                            pass
        return " ".join(text_chunks)[:25000].strip()
    except Exception:
        return ''


def _extract_pdf_text(raw_bytes: bytes) -> str:
    if PYPDF_AVAILABLE and PdfReader is not None:
        try:
            reader = PdfReader(io.BytesIO(raw_bytes))
            chunks = []
            for page in reader.pages[:15]:
                txt = (page.extract_text() or '').strip()
                if txt:
                    chunks.append(txt)
            if chunks:
                return "\n\n".join(chunks)[:25000]
        except Exception:
            pass
    return _extract_pdf_text_pure_python(raw_bytes)


def _build_attachment_blocks(attachments: list[dict] | None) -> tuple[list[dict], list[str], list[str]]:
    """
    Converts uploaded attachments into Gemini Interactions API content blocks
    and extracts text from TXT/MD/PDF files for both speed and fallback processing.
    """
    blocks = []
    text_snippets = []
    attachment_names = []
    for att in (attachments or [])[:3]:
        filename = str(att.get('filename') or 'notes')
        attachment_names.append(filename)
        mime = str(att.get('mimeType') or 'application/octet-stream').lower().strip()
        b64 = str(att.get('dataBase64') or '').strip()
        if not b64:
            continue

        ext = filename.rsplit('.', 1)[-1].lower() if '.' in filename else ''
        if (mime.startswith('text/') and mime != 'text/csv') or ext in ('txt', 'md'):
            try:
                decoded = base64.b64decode(b64).decode('utf-8', errors='replace')[:25000]
                text_snippets.append(f"[Uploaded Notes: {filename}]\n{decoded}")
                blocks.append({'type': 'text', 'text': f"[Uploaded Notes: {filename}]\n{decoded}"})
            except Exception:
                pass
        elif mime.startswith('image/') or ext in ('png', 'jpg', 'jpeg', 'webp'):
            img_mime = mime if mime.startswith('image/') else (
                'image/png' if ext == 'png' else ('image/webp' if ext == 'webp' else 'image/jpeg')
            )
            blocks.append({'type': 'image', 'data': b64, 'mime_type': img_mime})
        elif mime in ('application/pdf', 'text/csv') or ext in ('pdf', 'csv'):
            doc_mime = 'text/csv' if (mime == 'text/csv' or ext == 'csv') else 'application/pdf'
            if doc_mime == 'application/pdf':
                try:
                    raw_bytes = base64.b64decode(b64)
                except Exception:
                    raw_bytes = b''
                extracted = _extract_pdf_text(raw_bytes) if raw_bytes else ''
                if extracted:
                    text_snippets.append(f"[Uploaded PDF: {filename}]\n{extracted}")
                    blocks.append({'type': 'text', 'text': f"[Uploaded PDF: {filename}]\n{extracted}"})
                # Keep binary PDF only if text extraction was sparse (e.g., scanned PDF) and size <= 1.5MB
                if len(extracted) < 120 and len(raw_bytes) <= 1_500_000:
                    blocks.append({'type': 'document', 'data': b64, 'mime_type': 'application/pdf'})
            else:
                try:
                    decoded = base64.b64decode(b64).decode('utf-8', errors='replace')[:25000]
                    text_snippets.append(f"[Uploaded CSV: {filename}]\n{decoded}")
                    blocks.append({'type': 'text', 'text': f"[Uploaded CSV: {filename}]\n{decoded}"})
                except Exception:
                    blocks.append({'type': 'document', 'data': b64, 'mime_type': doc_mime})
    return blocks, text_snippets, attachment_names


def run_copilot_chat(
    user: User,
    message: str,
    history: list[dict] | None = None,
    language: str = 'en',
    screen_context: str | None = None,
    attachments: list[dict] | None = None,
) -> dict:
    role = canonical_copilot_role(user.role)
    if role not in ('student', 'teacher', 'admin'):
        return {
            'reply': f"AI Copilot is currently enabled for Student, Teacher, and Admin roles (your role: {user.role}).",
            'role': role,
            'mode': 'unsupported_role',
            'cards': [],
            'pendingActions': [],
            'toolsUsed': [],
            'suggestedPrompts': [],
        }

    attachment_blocks, text_snippets, attachment_names = _build_attachment_blocks(attachments)
    clean_msg = (message or '').strip()
    if not clean_msg and attachment_blocks:
        clean_msg = (
            "Generate a structured assessment paper with answer key based strictly on the attached notes."
            if role == 'teacher'
            else "Summarize the attached notes and create practice questions."
        )
    if not clean_msg:
        return {
            'reply': 'Please type a question or attach notes so I can help.',
            'role': role,
            'mode': 'validation',
            'cards': [],
            'pendingActions': [],
            'toolsUsed': [],
            'suggestedPrompts': get_role_suggestions(role, language),
        }

    fallback_prompt = clean_msg
    if text_snippets:
        fallback_prompt = f"{clean_msg}\n\n" + "\n\n".join(text_snippets)

    api_key = Config.GEMINI_API_KEY
    if not (GENAI_AVAILABLE and api_key):
        return _run_local_fallback(
            user,
            role,
            fallback_prompt,
            uploaded_texts=text_snippets,
            attachment_names=attachment_names,
            fallback_reason='missing_api_key' if not api_key else 'genai_sdk_unavailable',
        )

    client_kwargs = {'api_key': api_key}
    timeout_ms = 28000 if attachment_blocks else 18000
    if genai_types is not None and hasattr(genai_types, 'HttpOptions'):
        client_kwargs['http_options'] = genai_types.HttpOptions(timeout=timeout_ms)

    candidate_models = [Config.GEMINI_MODEL]
    for fallback_model in ('gemini-3.5-flash-lite', 'gemini-3.1-flash-lite'):
        if fallback_model not in candidate_models:
            candidate_models.append(fallback_model)

    terminal_tools = {
        'format_assessment_paper',
        'format_lesson_plan',
        'format_study_practice_card',
        'generate_executive_report',
    }
    last_error = None

    for model_name in candidate_models:
        try:
            client = genai.Client(**client_kwargs)
            tools = get_tools_for_role(role)
            system_instruction = _build_system_instruction(user, role, language, screen_context)
            if attachment_blocks:
                system_instruction += (
                    "\nThe user has attached notes/documents/images. Base generated exam papers, quizzes, "
                    "lesson plans, practice questions, notices, or summaries directly on the attached material."
                )

            # Build stateless input history in Interactions API schema
            input_turns = []
            for item in (history or [])[-8:]:
                sender = (item.get('sender') or item.get('role') or 'user').lower()
                text = (item.get('text') or item.get('content') or '').strip()
                if not text:
                    continue
                if sender in ('assistant', 'model', 'copilot'):
                    input_turns.append({
                        'type': 'model_output',
                        'content': [{'type': 'text', 'text': text}],
                    })
                else:
                    input_turns.append({
                        'type': 'user_input',
                        'content': [{'type': 'text', 'text': text}],
                    })

            user_content = list(attachment_blocks)
            user_content.append({'type': 'text', 'text': clean_msg})
            input_turns.append({
                'type': 'user_input',
                'content': user_content,
            })

            cards = []
            pending_actions = []
            tools_used = []
            final_text = ''

            for _ in range(5):  # max 5 tool-calling rounds
                interaction = client.interactions.create(
                    model=model_name,
                    store=False,
                    system_instruction=system_instruction,
                    input=input_turns,
                    tools=tools,
                )

                fc_steps = []
                text_parts = []
                for step in (interaction.steps or []):
                    step_dict = step.model_dump() if hasattr(step, 'model_dump') else dict(step)
                    input_turns.append(step_dict)
                    stype = getattr(step, 'type', None)
                    if stype == 'function_call':
                        fc_steps.append(step)
                    elif stype == 'model_output':
                        for part in (getattr(step, 'content', None) or []):
                            if getattr(part, 'type', None) == 'text' and getattr(part, 'text', None):
                                text_parts.append(part.text)

                if not fc_steps:
                    final_text = (interaction.output_text or "\n".join(text_parts) or '').strip()
                    break

                all_terminal = True
                for fc in fc_steps:
                    tools_used.append(fc.name)
                    if fc.name not in terminal_tools and not fc.name.startswith('draft_'):
                        all_terminal = False
                    result = execute_tool(role, user, fc.name, fc.arguments or {})
                    _extract_cards_and_actions(fc.name, result, cards, pending_actions)
                    input_turns.append({
                        'type': 'function_result',
                        'name': fc.name,
                        'call_id': fc.id,
                        'result': [{'type': 'text', 'text': json.dumps(result, default=str)}],
                    })

                # Fast return: formatting & draft tools already produce complete UI cards
                if all_terminal:
                    if text_parts:
                        final_text = "\n".join(text_parts).strip()
                    elif cards:
                        final_text = f"Created **{cards[-1].get('title', 'document')}** — you can review or copy it below."
                    elif pending_actions:
                        final_text = f"Drafted **{pending_actions[-1].get('title', 'action')}** — review and tap **Confirm & Execute** below."
                    break

            if not final_text:
                final_text = "Done — check the details below."

            return {
                'reply': final_text,
                'role': role,
                'mode': 'gemini',
                'model': model_name,
                'cards': cards,
                'pendingActions': pending_actions,
                'toolsUsed': tools_used,
                'suggestedPrompts': get_role_suggestions(role, language),
            }
        except Exception as exc:
            last_error = f"{type(exc).__name__}: {str(exc)[:140]}"
            continue

    # Graceful degradation so CampusOS Copilot never crashes even if API is busy/offline
    return _run_local_fallback(
        user,
        role,
        fallback_prompt,
        uploaded_texts=text_snippets,
        attachment_names=attachment_names,
        fallback_reason=last_error,
    )
