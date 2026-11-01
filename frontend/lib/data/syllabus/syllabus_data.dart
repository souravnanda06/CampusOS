class SyllabusData {
  static const Map<String, List<String>> subjects = {
    // B.Tech Branches
    'B.Tech_CSE_1st': ['Mathematics-I', 'Physics', 'Basic Electrical', 'Engineering Mechanics', 'English', 'C Programming'],
    'B.Tech_CSE_2nd': ['Mathematics-III', 'Data Structures', 'Digital Logic', 'OOPs using C++', 'Economics', 'Environmental Science'],
    'B.Tech_CSE_3rd': ['Algorithms', 'DBMS', 'Operating Systems', 'Computer Org', 'Java Programming', 'Formal Languages'],
    'B.Tech_CSE_4th': ['Computer Networks', 'Compiler Design', 'Software Engg', 'Web Technology', 'AI & ML', 'Cloud Computing'],

    // New Branches (AIML, DS)
    'B.Tech_CSE-AIML_1st': ['Math for AI', 'Python for DS', 'Intro to AI', 'Statistics', 'C Programming', 'Ethics in AI'],
    'B.Tech_CSE-DS_1st': ['Data Science Intro', 'Statistics', 'Python', 'Linear Algebra', 'Databases', 'Visualization'],
    
    // B.Tech Other Branches
    'B.Tech_EE_1st': ['Mathematics-I', 'Physics', 'Electrical Circuits', 'Engineering Drawing'],
    'B.Tech_Civil_1st': ['Mathematics-I', 'Physics', 'Mechanics of Solids', 'Surveying'],
    'B.Tech_ECE_1st': ['Mathematics-I', 'Physics', 'Basic Electronics', 'Network Analysis'],

    // BCA (No Branch)
    'BCA_None_1st': ['Mathematics-I', 'Computer Fundamentals', 'C Programming', 'Digital Electronics', 'Communication Skills', 'PC Software'],
    'BCA_None_2nd': ['Data Structures', 'OS', 'OOPs C++', 'Discrete Math', 'Accounting', 'Environmental Studies'],
    'BCA_None_3rd': ['Java', 'DBMS', 'Computer Networks', 'Web Tech', 'Software Engg', 'Python'],

    // MCA (No Branch)
    'MCA_None_1st': ['Adv Data Structures', 'Adv OS', 'AI', 'Prob & Stats', 'Java', 'Cloud'],
    'MCA_None_2nd': ['Machine Learning', 'Big Data', 'Network Security', 'IoT', 'Research Methodology'],
  };

  static List<String> getSubjects(String? course, String? branch, String? year) {
    // If BCA/MCA is selected, branch might be null, so we use "None" as the key
    String safeBranch = (branch == null || branch.isEmpty) ? "None" : branch;
    String key = "${course}_${safeBranch}_$year";
    
    return subjects[key] ?? ['General', 'Lab', 'Seminar', 'Project', 'Other'];
  }
}
