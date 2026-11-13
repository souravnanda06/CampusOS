"""
CampusOS Career Hub: AI Resume ATS Analyzer & Recommendation Service.

Uses pypdf for text extraction and Gemini Flash via google-genai for ATS scoring,
keyword gap analysis, bullet polish recommendations, and tailored interview prep questions.
Includes an intelligent deterministic heuristic fallback when GEMINI_API_KEY is not configured or offline.
"""

import io
import json
import os
import re
from config import Config

try:
    from pypdf import PdfReader
    PYPDF_AVAILABLE = True
except ImportError:
    PdfReader = None
    PYPDF_AVAILABLE = False

try:
    from google import genai
    from google.genai import types as genai_types
    GENAI_AVAILABLE = True
except ImportError:
    genai = None
    genai_types = None
    GENAI_AVAILABLE = False


def extract_text_from_pdf(pdf_bytes: bytes) -> str:
    """Extracts raw plain text from PDF bytes using pypdf."""
    if not PYPDF_AVAILABLE or not pdf_bytes:
        return ""
    try:
        reader = PdfReader(io.BytesIO(pdf_bytes))
        pages_text = []
        for page in reader.pages:
            text = page.extract_text()
            if text:
                pages_text.append(text)
        return "\n".join(pages_text).strip()
    except Exception as e:
        print(f"[WARN] [ATS] PDF text extraction failed: {e}")
        return ""


def analyze_resume_ats(
    resume_text: str,
    target_role: str = "Software Engineer",
    target_skills: list = None
) -> dict:
    """
    Analyzes student resume text against target role and skills.
    Returns structured ATS scoring, keyword gaps, and actionable feedback.
    """
    if not target_skills:
        target_skills = ["Data Structures", "Algorithms", "Python", "SQL", "Git", "REST APIs", "Problem Solving"]

    # In testing mode, directly use the fast deterministic heuristic engine
    if getattr(Config, 'TESTING', False) or os.environ.get('TESTING') == 'true':
        return _heuristic_ats_analysis(resume_text, target_role, target_skills)

    # If Gemini is available and configured, use AI analysis
    api_key = getattr(Config, 'GEMINI_API_KEY', None) or os.environ.get('GEMINI_API_KEY')
    if GENAI_AVAILABLE and api_key and len(resume_text) > 50:
        try:
            client = genai.Client(api_key=api_key)
            prompt = f"""
You are an expert Technical Recruiter and Applicant Tracking System (ATS) auditor for engineering campus placements.
Analyze the following student resume for the target role: "{target_role}".
Target skills: {', '.join(target_skills)}.

Resume Text:
\"\"\"
{resume_text[:6000]}
\"\"\"

Provide an objective assessment in valid JSON with this exact structure:
{{
  "atsScore": <integer between 40 and 98>,
  "summary": "<2-sentence executive summary of profile strength>",
  "strengths": ["<strength 1>", "<strength 2>", "<strength 3>"],
  "missingKeywords": ["<missing high-value skill 1>", "<missing skill 2>", "<missing skill 3>"],
  "formattingTips": ["<actionable formatting or bullet point tip 1>", "<tip 2>"],
  "sampleInterviewQuestions": [
    "<Technical question 1 based on their listed projects or target role>",
    "<Technical question 2>",
    "<Behavioral/situational question 3>"
  ]
}}
Respond ONLY with the JSON object.
"""
            response = client.models.generate_content(
                model="gemini-3.8-flash",
                contents=prompt,
                config=genai_types.GenerateContentConfig(
                    temperature=0.2,
                    response_mime_type="application/json"
                )
            )
            raw_text = (response.text or "").strip()
            # Clean markdown codeblocks if present
            if raw_text.startswith("```"):
                raw_text = re.sub(r"^```(?:json)?\n?", "", raw_text)
                raw_text = re.sub(r"\n?```$", "", raw_text)
            parsed = json.loads(raw_text)
            parsed['analyzedWith'] = 'GEMINI_AI'
            return parsed
        except Exception as e:
            print(f"[WARN] [ATS] Gemini analysis failed or throttled: {e}. Falling back to heuristic engine.")

    # Deterministic Heuristic Fallback Engine
    return _heuristic_ats_analysis(resume_text, target_role, target_skills)


def _heuristic_ats_analysis(resume_text: str, target_role: str, target_skills: list) -> dict:
    """Deterministic, robust ATS scoring engine when AI is offline."""
    lower_text = resume_text.lower()
    score = 55  # Base score

    found_skills = []
    missing_skills = []

    # Essential industry tech skills to search for
    tech_keywords = [
        "python", "java", "c++", "c", "javascript", "typescript", "flutter", "dart",
        "react", "node", "sql", "mysql", "mongodb", "git", "github", "docker",
        "rest api", "data structures", "algorithms", "linux", "html", "css",
        "machine learning", "oop", "dbms", "operating systems"
    ]

    all_targets = set([s.lower() for s in target_skills] + tech_keywords)

    for skill in all_targets:
        if re.search(r'\b' + re.escape(skill) + r'\b', lower_text):
            found_skills.append(skill.title())
        elif skill in [s.lower() for s in target_skills]:
            missing_skills.append(skill.title())

    # Section completeness checks
    has_education = bool(re.search(r'\b(education|b\.?tech|bput|university|cgpa|percentage)\b', lower_text))
    has_projects = bool(re.search(r'\b(project|projects|built|developed|implemented)\b', lower_text))
    has_skills_section = bool(re.search(r'\b(skills|technical skills|technologies|proficiencies)\b', lower_text))
    has_experience = bool(re.search(r'\b(experience|internship|training|work experience)\b', lower_text))
    has_contact = bool(re.search(r'[\w\.-]+@[\w\.-]+\.\w+', lower_text)) or bool(re.search(r'\b\d{10}\b', lower_text))

    if has_education:
        score += 8
    if has_projects:
        score += 12
    if has_skills_section:
        score += 8
    if has_experience:
        score += 7
    if has_contact:
        score += 5

    # Skills density bonus
    skill_bonus = min(len(found_skills) * 2, 18)
    score += skill_bonus

    # Normalize between 45 and 95
    score = max(45, min(94, score))

    strengths = []
    if found_skills:
        strengths.append(f"Demonstrated foundational technical skills: {', '.join(found_skills[:4])}")
    if has_projects:
        strengths.append("Project portfolio section is present with practical development evidence")
    if has_education:
        strengths.append("Academic background and degree credentials clearly structured")
    if not strengths:
        strengths.append("Clear contact and foundational educational structure")

    formatting_tips = []
    if not has_experience:
        formatting_tips.append("Add an Internship, Open-Source contribution, or Academic Project section to demonstrate practical execution.")
    if len(found_skills) < 5:
        formatting_tips.append("Explicitly group your skills by category (Languages, Frameworks, Developer Tools, Databases).")
    formatting_tips.append("Use the XYZ formula for bullet points: 'Accomplished [X], as measured by [Y], by doing [Z]'.")
    formatting_tips.append("Ensure your GitHub and LinkedIn profile hyperlinks are active and placed at the top.")

    sample_questions = [
        f"Can you explain the architectural choices and data flow in your primary project?",
        f"How would you optimize database queries or algorithm time complexity for the {target_role} stack?",
        f"Describe a challenging bug you encountered and how you systematically isolated the root cause."
    ]

    return {
        "atsScore": score,
        "summary": f"Your profile shows a solid foundation for {target_role} roles with {len(found_skills)} verified core skills.",
        "strengths": strengths,
        "missingKeywords": missing_skills[:5] if missing_skills else ["System Design", "Cloud Basics (AWS/GCP)", "CI/CD"],
        "formattingTips": formatting_tips,
        "sampleInterviewQuestions": sample_questions,
        "analyzedWith": "HEURISTIC_RULE_ENGINE"
    }
