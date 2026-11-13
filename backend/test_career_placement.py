import unittest
import json
import os
import sys

# Ensure backend root is in sys.path
backend_dir = os.path.dirname(os.path.abspath(__file__))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

os.environ['TESTING'] = 'true'

from app import create_app
from extensions import db
from models.user import User
from models.career import (
    PlacementDrive,
    OpportunityListing,
    PlacementApplication,
    StudentCareerProfile,
)


class TestCareerPlacementModule(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = create_app()
        cls.app.config['TESTING'] = True
        cls.client = cls.app.test_client()

        with cls.app.app_context():
            # Create a test student user
            cls.student = User.query.filter_by(email="student.test.placement@campusos.edu").first()
            if not cls.student:
                cls.student = User(
                    name="Aarav Sharma",
                    email="student.test.placement@campusos.edu",
                    password="hashed_password",
                    role="student",
                    registration_number="2201105088",
                    course="B.Tech",
                    branch="CSE",
                    year="2026"
                )
                db.session.add(cls.student)
                db.session.commit()

            # Create a test admin user
            cls.admin = User.query.filter_by(email="admin.tpo.placement@campusos.edu").first()
            if not cls.admin:
                cls.admin = User(
                    name="Dr. TPO Director",
                    email="admin.tpo.placement@campusos.edu",
                    password="hashed_password",
                    role="admin"
                )
                db.session.add(cls.admin)
                db.session.commit()

            # Generate tokens using official CampusOS helper
            from utils.crypto import create_access_token
            cls.student_token = create_access_token(cls.student)
            cls.admin_token = create_access_token(cls.admin)

    def test_01_hub_summary(self):
        """Test the student career hub summary metrics."""
        res = self.client.get(
            '/api/career/hub-summary',
            headers={'Authorization': f'Bearer {self.student_token}'}
        )
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertIn('activeDrivesCount', data)
        self.assertIn('externalOpportunitiesCount', data)
        self.assertIn('studentAtsScore', data)
        self.assertGreater(data['activeDrivesCount'], 0)

    def test_02_list_drives_and_eligibility(self):
        """Test on-campus drives with dynamic eligibility calculations."""
        res = self.client.get(
            '/api/career/drives',
            headers={'Authorization': f'Bearer {self.student_token}'}
        )
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertIn('drives', data)
        drives = data['drives']
        self.assertGreater(len(drives), 0)
        first_drive = drives[0]
        self.assertIn('isEligible', first_drive)
        self.assertIn('companyName', first_drive)
        self.assertIn('ctcBreakdown', first_drive)

    def test_03_apply_to_drive(self):
        """Test 1-tap student application to an on-campus drive."""
        # Get first drive
        res = self.client.get(
            '/api/career/drives',
            headers={'Authorization': f'Bearer {self.student_token}'}
        )
        first_drive = res.get_json()['drives'][0]
        drive_id = first_drive['id']

        # Apply
        res_apply = self.client.post(
            f'/api/career/drives/{drive_id}/apply',
            headers={'Authorization': f'Bearer {self.student_token}'}
        )
        self.assertIn(res_apply.status_code, (200, 201))
        data_apply = res_apply.get_json()
        self.assertIn('application', data_apply)
        self.assertEqual(data_apply['application']['driveId'], drive_id)

    def test_04_list_opportunities(self):
        """Test external & curated opportunities filtering."""
        res = self.client.get('/api/career/opportunities')
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertIn('opportunities', data)
        self.assertGreater(data['count'], 0)

    def test_05_profile_and_ats_analysis(self):
        """Test student career profile updates and ATS resume analysis."""
        # Update profile
        res_prof = self.client.post(
            '/api/career/profile',
            headers={'Authorization': f'Bearer {self.student_token}'},
            json={
                "skills": ["Flutter", "Python", "SQL", "Docker", "Git"],
                "githubUrl": "https://github.com/campusos-student",
                "linkedinUrl": "https://linkedin.com/in/campusos-student",
                "cgpa": 8.6
            }
        )
        self.assertEqual(res_prof.status_code, 200)
        prof_data = res_prof.get_json()['profile']
        self.assertIn('Flutter', prof_data['skills'])
        self.assertEqual(prof_data['cgpa'], 8.6)

        # ATS analysis test with simulated text
        res_ats = self.client.post(
            '/api/career/resume/analyze',
            headers={'Authorization': f'Bearer {self.student_token}'},
            json={
                "resumeText": "Experienced B.Tech CSE student with strong projects in Flutter, Python, and SQL. Built CampusOS mobile application. Education: B.Tech (CGPA: 8.6).",
                "targetRole": "Mobile Application Developer"
            }
        )
        self.assertEqual(res_ats.status_code, 200)
        ats_data = res_ats.get_json()
        self.assertIn('atsAnalysis', ats_data)
        self.assertGreaterEqual(ats_data['atsAnalysis']['atsScore'], 50)
        self.assertIn('strengths', ats_data['atsAnalysis'])

    def test_06_admin_analytics_and_applicants(self):
        """Test admin drive applicants retrieval and placement analytics."""
        res_drives = self.client.get(
            '/api/career/drives',
            headers={'Authorization': f'Bearer {self.student_token}'}
        )
        drive_id = res_drives.get_json()['drives'][0]['id']

        # Get applicants as admin
        res_app = self.client.get(
            f'/api/admin/career/drives/{drive_id}/applicants',
            headers={'Authorization': f'Bearer {self.admin_token}'}
        )
        self.assertEqual(res_app.status_code, 200)
        app_data = res_app.get_json()
        self.assertIn('applicants', app_data)

        # Get placement analytics
        res_stat = self.client.get(
            '/api/admin/career/analytics',
            headers={'Authorization': f'Bearer {self.admin_token}'}
        )
        self.assertEqual(res_stat.status_code, 200)
        stat_data = res_stat.get_json()
        self.assertIn('branchBreakdown', stat_data)
        self.assertIn('averagePackage', stat_data)

    def test_07_smart_profile_extended_fields(self):
        """Test extended smart profile fields: projects, certs, bio, targetRole."""
        res = self.client.post(
            '/api/career/profile',
            headers={'Authorization': f'Bearer {self.student_token}'},
            json={
                "targetRole": "Mobile Platform Engineer",
                "bio": "Building high-performance Flutter & distributed systems.",
                "skills": ["Flutter", "Dart", "Python", "SQLite"],
                "projects": [
                    {
                        "id": "proj-1",
                        "title": "CampusOS Mobile",
                        "description": "Unified institutional platform with offline Ed25519 QR passports.",
                        "techStack": ["Flutter", "Dart", "BLE"],
                        "githubUrl": "https://github.com/campusos",
                        "liveUrl": "https://campusos.edu"
                    }
                ],
                "certifications": [
                    {
                        "id": "cert-1",
                        "title": "Google Cloud Associate Cloud Engineer",
                        "issuer": "Google Cloud",
                        "issueDate": "2026-04",
                        "credentialUrl": "https://google.com/cert/123"
                    }
                ],
                "academicRecords": {
                    "tenthPercentage": 94.2,
                    "twelfthPercentage": 91.0,
                    "cgpa": 8.8
                }
            }
        )
        self.assertEqual(res.status_code, 200)
        prof = res.get_json()['profile']
        self.assertEqual(prof['targetRole'], "Mobile Platform Engineer")
        self.assertEqual(len(prof['projects']), 1)
        self.assertEqual(prof['projects'][0]['title'], "CampusOS Mobile")
        self.assertEqual(len(prof['certifications']), 1)
        self.assertEqual(prof['academicRecords']['tenthPercentage'], 94.2)

    def test_08_resources_and_news(self):
        """Test learning resources and tech news feed endpoints."""
        res_res = self.client.get('/api/career/resources')
        self.assertEqual(res_res.status_code, 200)
        res_data = res_res.get_json()
        self.assertIn('resources', res_data)
        self.assertGreaterEqual(res_data['count'], 4)

        res_news = self.client.get('/api/career/news')
        self.assertEqual(res_news.status_code, 200)
        news_data = res_news.get_json()
        self.assertIn('news', news_data)
        self.assertGreaterEqual(news_data['count'], 2)

    def test_09_resume_data_and_copilot_chat(self):
        """Test resume data synthesis and career copilot chat response."""
        res_resume = self.client.get(
            '/api/career/resume/data',
            headers={'Authorization': f'Bearer {self.student_token}'}
        )
        self.assertEqual(res_resume.status_code, 200)
        r_data = res_resume.get_json()
        self.assertIn('student', r_data)
        self.assertIn('skills', r_data)
        self.assertIn('projects', r_data)

        res_copilot = self.client.post(
            '/api/career/copilot/chat',
            headers={'Authorization': f'Bearer {self.student_token}'},
            json={
                "message": "Give me a mock technical question for a Software Engineer interview."
            }
        )
        self.assertEqual(res_copilot.status_code, 200)
        c_data = res_copilot.get_json()
        self.assertIn('reply', c_data)
        self.assertIn('sender', c_data)


if __name__ == '__main__':
    unittest.main()
