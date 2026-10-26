import 'package:flutter/material.dart';

class LocalizationService {
  LocalizationService._();
  static final LocalizationService instance = LocalizationService._();

  final ValueNotifier<String> currentLocale = ValueNotifier<String>('en');

  final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'dashboard': 'Dashboard',
      'report_crime': 'Report Crime',
      'threat_scanner': 'Threat Scanner',
      'cyber_news': 'Cyber News',
      'rewards': 'Rewards',
      'contact_us': 'Contact Us',
      'sessions': '1:1 Session',
      'scan_system': 'Scan System',
      'emergency': 'Emergency',
      'nav_protection': 'Protection',
      'nav_support': 'Support',
      'nav_about': 'About',
      'assistant_open': 'Open Cyber Uday Assistant',
      'assistant_close': 'Close Cyber Uday Assistant',
      'assistant_title': 'Cyber Uday Assistant',
      'assistant_subtitle': 'Your digital safety companion',
      'assistant_prompt': 'How can I help you stay safe?',
      'assistant_check_link': 'Check a suspicious link',
      'assistant_scammed': 'I think I was scammed',
      'assistant_bank_security': 'Bank security',
      'assistant_phone_hacked': 'My phone may be hacked',
      'assistant_emergency': 'Emergency help',
      'assistant_report_crime': 'Report cybercrime',
      'assistant_ask': 'Ask Cyber Uday',
      'welcome': 'Welcome Back',
      'hacked_btn': 'I AM HACKED',
      'hacked_title': 'EMERGENCY: Account Breach Detected',
      'hacked_desc':
          'Initiating bank freeze, securing personal data, and notifying authorities...',
      'freeze_bank': 'Freeze My Bank',
      'connect_bank': 'Connect Bank',
      'total_reports': 'Total Reports',
      'threats_blocked': 'Threats Blocked',
      'hero_title':
          'The digital war begins where fraud targets ordinary people.',
      'dashboard_greeting': 'Welcome back',
      'dashboard_intro': 'Your digital safety, at a glance.',
      'dashboard_protection_title': 'Your protection overview',
      'dashboard_protection_description':
          'Your personal activity will appear here after you scan, report, or request help.',
      'dashboard_protection_status': 'Ready to help',
      'dashboard_quick_actions': 'What do you need today?',
      'dashboard_quick_actions_subtitle':
          'Start with the action that matches your situation.',
      'dashboard_activity_title': 'Recent activity',
      'dashboard_activity_subtitle':
          'Keep track of your safety actions in one place.',
      'dashboard_activity_empty':
          'No personal activity to show yet. Scan a link or submit a report to get started.',
      'dashboard_services_title': 'More from Cyber Uday',
      'dashboard_services_subtitle':
          'Explore support and safety services when you need them.',
      'dashboard_emergency_description':
          'If you believe an account or device is compromised, review the next step before sending an emergency request.',
      'dashboard_get_help': 'Review emergency help',
      'dashboard_emergency_logged':
          'Your emergency request was saved for support.',
      'dashboard_bank_connecting':
          'Saving your bank support permission request...',
      'dashboard_bank_connected':
          'Your bank support permission request was saved. No bank credentials were collected.',
      'dashboard_action_failed':
          'We could not complete that action. Please try again.',
      'profile_title': 'Profile',
      'profile_back': 'Back',
      'profile_header_title': 'Profile',
      'profile_header_subtitle':
          'Manage your Cyber Uday account and preferences.',
      'profile_account_label': 'Cyber Uday account',
      'profile_avatar_label': 'Account profile image',
      'profile_account_group': 'Account',
      'profile_account_group_description': 'Preferences for your experience.',
      'profile_preferences_group': 'Preferences',
      'profile_preferences_description': 'Language settings for this device.',
      'profile_support_group': 'Support',
      'profile_support_group_description': 'Help from the Cyber Uday team.',
      'profile_language': 'Language',
      'profile_language_subtitle':
          'Choose the language used across Cyber Uday.',
      'profile_help': 'Help & Support',
      'profile_help_subtitle': 'Contact the Cyber Uday team.',
      'profile_citizen_fallback': 'Cyber Uday citizen',
      'profile_signout_title': 'Sign out of Cyber Uday?',
      'profile_signout_description':
          'You can sign in again whenever you are ready.',
      'profile_signout_confirm': 'Sign out',
      'profile_sign_out': 'Sign out',
      'cancel': 'Cancel',
      'developers': 'Developers',
      'dashboard_action_scanner': 'Threat Scanner',
      'dashboard_action_scanner_description':
          'Check a suspicious link or message.',
      'dashboard_action_report': 'Report Cybercrime',
      'dashboard_action_report_description': 'Start a report with guided help.',
      'dashboard_action_emergency': 'Emergency Help',
      'dashboard_action_emergency_description':
          'Reach emergency contacts quickly.',
      'dashboard_action_bank': 'Connect Bank',
      'dashboard_action_bank_description':
          'Save a permission request for support.',
      'bank_security': 'Bank Security',
      'bank_security_title': 'Bank Security',
      'bank_security_intro':
          'Protect and manage your banking support permissions with Cyber Uday.',
      'bank_security_loading': 'Checking your saved support permission...',
      'bank_security_permission_title': 'Support permission request saved',
      'bank_security_permission_none': 'No support permission requested yet',
      'bank_security_permission_description':
          'This records your request for Cyber Uday support. It does not connect a bank or collect bank credentials.',
      'bank_security_credentials_note':
          'Cyber Uday does not collect bank credentials here. Any future bank connection will require an authorized integration and your consent.',
      'bank_security_request': 'Request support',
      'bank_security_update': 'Update request',
      'bank_security_load_failed': 'Permission status unavailable',
      'bank_security_load_failed_description':
          'We could not read your saved support permission. You can try submitting a new request.',
      'bank_security_permission_saved_message':
          'Your bank support permission request was saved.',
      'bank_security_permission_failed':
          'We could not save the bank support permission request.',
      'dashboard_bank_security_description':
          'Review bank support permissions without sharing bank credentials.',
      'dashboard_bank_security_view': 'View Bank Security',
      'dashboard_latest_news_title': 'Latest cyber news',
      'dashboard_latest_news_subtitle':
          'Stay informed with current technology and security links.',
      'dashboard_view_all': 'View all',
      'dashboard_latest_news_loading': 'Loading latest news...',
      'dashboard_latest_news_error': 'Latest news is unavailable right now.',
      'dashboard_latest_news_empty': 'No latest news is available right now.',
      'dashboard_latest_news_open_failed': 'Could not open this news link.',
      'retry': 'Try again',
      'language_english': 'English',
      'language_hindi': 'Hindi',
      'language_marathi': 'Marathi',
      'admin': 'Admin',
      'brand_tagline': 'Your digital safety home.',
      'scanner_page_title':
          'Threat scanner for suspicious links, apps, and screenshots.',
      'scanner_page_subtitle':
          'Submit a website, app link, or image evidence for a guided safety review.',
      'scanner_submit_title': 'Submit a suspicious asset',
      'scanner_submit_subtitle':
          'Paste a suspicious link or add evidence so the virtual team can inspect risk.',
      'scanner_link_label': 'Website or phishing link',
      'scanner_app_label': 'App name or APK source link',
      'scanner_note_label': 'Image or evidence note',
      'scanner_upload': 'Upload image',
      'scanner_submit': 'Submit to virtual team',
      'scanner_fill_one': 'Please fill at least one field.',
      'scanner_submitted': 'Threat submitted to the virtual team for analysis.',
      'scanner_picker_opening': 'Image picker opening...',
      'report_page_title': 'AI report generation for cybercrime victims.',
      'report_page_subtitle':
          'Use guided intake to organize the incident, evidence, and timeline into a report.',
      'report_workflow_title': 'AI-assisted workflow',
      'report_workflow_subtitle':
          'Speak or type what happened. Cyber Uday helps organize the facts into a formal report.',
      'report_description_label': 'Describe the attack or fraud',
      'report_timeline_label': 'Victim details and timeline',
      'report_evidence_label': 'Evidence links, screenshots, UPI IDs',
      'report_chat_ai': 'Chat with AI',
      'report_generate_pdf': 'Generate PDF report',
      'report_destination_title': 'Submit destination',
      'report_destination_subtitle':
          'Choose whether the report goes to the Cyber Uday team or the cyber cell.',
      'report_submit_team': 'Submit to our team',
      'report_submit_cell': 'Submit to cyber cell',
      'report_describe_first': 'Please describe the attack.',
      'report_submitted': 'Report submitted to {destination} successfully.',
      'report_fill_first': 'Fill the details first or submit a report.',
      'emergency_page_title': 'Emergency help lines',
      'emergency_page_subtitle':
          'Immediate access to authorities and emergency services. One tap to call.',
      'call_label': 'Call: {number}',
      'news_page_title':
          'Stay aware with recent cybercrime news and citizen updates.',
      'news_page_subtitle':
          'Read verified news and citizen awareness updates sent to the team for review.',
      'news_recent_title': 'Recent news',
      'news_recent_subtitle':
          'Daily awareness feed for cyber fraud, fake lottery cases, and phishing alerts.',
      'news_empty': 'No news published yet.',
      'news_hacker_title': 'Hacker News',
      'news_hacker_subtitle':
          'Live technology and security links from Hacker News.',
      'news_hacker_error': 'Unable to load Hacker News right now.',
      'news_hacker_empty': 'No Hacker News stories available.',
      'news_refresh': 'Refresh',
      'news_create_title': 'Create new news',
      'news_create_subtitle':
          'Submit a local scam alert or suspicious pattern to the team before public posting.',
      'news_headline_label': 'Headline or fraud pattern',
      'news_content_label': 'What happened and where',
      'news_submit_team': 'Submit to team',
      'news_fill_all': 'Please fill all fields.',
      'news_submitted':
          'News submitted for review. It will appear once approved by admin.',
      'news_invalid_link': 'Invalid news link.',
      'news_open_failed': 'Could not open news link.',
      'scan_page_title': 'Scan your mobile and computer for threats.',
      'scan_page_subtitle':
          'Use guided security checks for mobile and computer threats.',
      'scan_mobile_title': 'Scan your mobile',
      'scan_mobile_subtitle':
          'Find risky permissions, fake loan apps, hidden overlays, and notification interception patterns.',
      'scan_mobile_action': 'Start mobile scan',
      'scan_computer_title': 'Scan your computer',
      'scan_computer_subtitle':
          'Check browser warnings, remote access exposure, phishing traces, and suspicious downloads.',
      'scan_computer_action': 'Start computer scan',
      'emergency_police': 'Police',
      'emergency_ambulance': 'Ambulance',
      'emergency_fire': 'Fire brigade',
      'emergency_cyber_cell': 'Cyber cell',
      'emergency_women': 'Women helpline',
      'emergency_child': 'Child helpline',
      'rewards_page_title':
          'Operative status, coins, premium support, and claim flow.',
      'rewards_page_subtitle':
          'Earn points by completing security habits and use them to unlock support.',
      'rewards_status_title': 'Operative status',
      'rewards_status_subtitle':
          'Track your balance, claim points, and complete your mobile challenge.',
      'rewards_balance': 'Balance',
      'rewards_points': 'Points claim',
      'rewards_challenge': 'Mobile challenge',
      'rewards_ready': 'Ready',
      'rewards_premium_title': 'Premium features',
      'rewards_premium_subtitle':
          'Premium unlocks direct team support, faster case handling, and near-continuous availability.',
      'rewards_team_support': 'Our team support to solve your case',
      'rewards_guidance': '24/7 solution guidance',
      'rewards_escalation': 'Priority escalation for high-risk reports',
      'rewards_claim': 'Claim points',
      'contact_options_title': 'Contact options',
      'contact_page_title':
          'Connect with the Cyber Uday team and support lines.',
      'contact_page_subtitle':
          'Use this page for help calls, collaboration, investment, or company tie-ups.',
      'contact_options_subtitle':
          'Speak to the team, start collaboration, or ask for direct assistance.',
      'contact_call_team': 'Call our team',
      'contact_collaborate': 'Collaborate with us',
      'contact_investment': 'Get investment support',
      'contact_help': 'Help me',
      'contact_company': 'Company tie-up',
      'contact_helpline_title': 'Helpline 24/7',
      'contact_helpline_subtitle':
          'Future integrations can route emergency context to the right service or Cyber Uday team.',
      'contact_fire': 'Fire vehicle',
      'contact_team': 'CYBER UDAY team',
      'developers_header': 'Meet the engineering team',
      'developers_description':
          'A focused group across cyber security, Flutter, AI, backend architecture, and user experience.',
      'developers_link_pending': 'This team link will be added later.',
      'link_open_failed': 'Could not open this link.',
      'sessions_page_title': 'Expert consultations',
      'sessions_page_subtitle':
          'Get one-on-one guidance from verified digital safety professionals.',
      'sessions_all': 'All',
      'sessions_security': 'Security',
      'sessions_legal': 'Legal',
      'sessions_mental_health': 'Mental health',
      'sessions_online': 'Online',
      'sessions_next_available': 'Next available',
      'sessions_per_30_minutes': 'Per 30 mins',
      'sessions_requested': 'Session requested',
      'sessions_request_sent':
          'Your request for a session with {name} has been sent. Our team will contact you within 15 minutes.',
      'sessions_got_it': 'Got it',
      'sessions_book': 'Book instant session',
      'assistant_download_report': 'Download generated report',
      'assistant_voice_title': 'Cyber voice interview',
      'assistant_voice_subtitle': 'Answering will generate your report',
      'assistant_listening': 'Listening...',
      'assistant_type_or_mic': 'Type or use mic...',
      'assistant_initial_greeting':
          'Hello! I am your Cyber Bodyguard. To help you report this incident, tell me exactly what happened?',
      'assistant_unavailable': 'I could not process that.',
      'assistant_connection_error':
          'I encountered a connection error. Can you please repeat that?',
      'splash_preparing': 'Preparing Cyber Uday',
      'splash_workspace': 'Preparing your workspace',
      'brand_bodyguard': 'Your Digital Bodyguard',
    },
    'hi': {
      'dashboard': 'डैशबोर्ड',
      'report_crime': 'अपराध रिपोर्ट करें',
      'threat_scanner': 'खतरा स्कैनर',
      'cyber_news': 'साइबर समाचार',
      'rewards': 'पुरस्कार',
      'contact_us': 'संपर्क करें',
      'sessions': '1:1 सत्र',
      'scan_system': 'सिस्टम स्कैन करें',
      'emergency': 'आपातकाल',
      'nav_protection': 'सुरक्षा',
      'nav_support': 'सहायता',
      'nav_about': 'परिचय',
      'assistant_open': 'साइबर उदय सहायक खोलें',
      'assistant_close': 'साइबर उदय सहायक बंद करें',
      'assistant_title': 'साइबर उदय सहायक',
      'assistant_subtitle': 'आपका डिजिटल सुरक्षा साथी',
      'assistant_prompt': 'मैं आपको सुरक्षित रहने में कैसे मदद करूँ?',
      'assistant_check_link': 'संदिग्ध लिंक जाँचें',
      'assistant_scammed': 'मुझे लगता है मेरे साथ धोखाधड़ी हुई',
      'assistant_bank_security': 'बैंक सुरक्षा',
      'assistant_phone_hacked': 'शायद मेरा फोन हैक हो गया है',
      'assistant_emergency': 'आपातकालीन सहायता',
      'assistant_report_crime': 'साइबर अपराध रिपोर्ट करें',
      'assistant_ask': 'साइबर उदय से पूछें',
      'welcome': 'वापसी पर स्वागत है',
      'hacked_btn': 'मैं हैक हो गया हूँ',
      'hacked_title': 'आपातकाल: खाता उल्लंघन का पता चला',
      'hacked_desc':
          'बैंक फ्रीज शुरू करना, व्यक्तिगत डेटा सुरक्षित करना और अधिकारियों को सूचित करना...',
      'freeze_bank': 'मेरा बैंक फ्रीज करें',
      'connect_bank': 'बैंक कनेक्ट करें',
      'total_reports': 'कुल रिपोर्ट',
      'threats_blocked': 'खतरे रोके गए',
      'hero_title':
          'डिजिटल युद्ध वहां शुरू होता है जहां धोखाधड़ी आम लोगों को निशाना बनाती है।',
      'dashboard_greeting': 'वापसी पर स्वागत है',
      'dashboard_intro': 'आपकी डिजिटल सुरक्षा, एक नज़र में।',
      'dashboard_protection_title': 'आपकी सुरक्षा का अवलोकन',
      'dashboard_protection_description':
          'स्कैन, रिपोर्ट या सहायता अनुरोध करने के बाद आपकी व्यक्तिगत गतिविधि यहाँ दिखाई देगी।',
      'dashboard_protection_status': 'मदद के लिए तैयार',
      'dashboard_quick_actions': 'आज आपको किस चीज़ की ज़रूरत है?',
      'dashboard_quick_actions_subtitle':
          'अपनी स्थिति के अनुसार कार्रवाई चुनें।',
      'dashboard_activity_title': 'हाल की गतिविधि',
      'dashboard_activity_subtitle':
          'अपनी सुरक्षा गतिविधियों पर एक ही जगह नज़र रखें।',
      'dashboard_activity_empty':
          'अभी कोई व्यक्तिगत गतिविधि नहीं है। शुरू करने के लिए किसी लिंक को स्कैन करें या रिपोर्ट भेजें।',
      'dashboard_services_title': 'साइबर उदय की अन्य सेवाएँ',
      'dashboard_services_subtitle':
          'ज़रूरत पड़ने पर सहायता और सुरक्षा सेवाएँ देखें।',
      'dashboard_emergency_description':
          'अगर आपका खाता या डिवाइस खतरे में है, तो आपातकालीन अनुरोध भेजने से पहले अगला कदम देखें।',
      'dashboard_get_help': 'आपातकालीन सहायता देखें',
      'dashboard_emergency_logged':
          'आपका आपातकालीन अनुरोध सहायता के लिए सुरक्षित किया गया है।',
      'dashboard_bank_connecting':
          'आपका बैंक सहायता अनुमति अनुरोध सहेजा जा रहा है...',
      'dashboard_bank_connected':
          'बैंक सहायता अनुमति अनुरोध सहेजा गया। बैंक क्रेडेंशियल एकत्र नहीं किए गए।',
      'dashboard_action_failed':
          'यह कार्रवाई पूरी नहीं हो सकी। कृपया फिर कोशिश करें।',
      'profile_title': 'प्रोफ़ाइल',
      'profile_back': 'वापस जाएँ',
      'profile_header_title': 'प्रोफ़ाइल',
      'profile_header_subtitle':
          'अपना साइबर उदय खाता और प्राथमिकताएँ प्रबंधित करें।',
      'profile_account_label': 'साइबर उदय खाता',
      'profile_avatar_label': 'खाता प्रोफ़ाइल छवि',
      'profile_account_group': 'खाता',
      'profile_account_group_description': 'आपके अनुभव की प्राथमिकताएँ।',
      'profile_preferences_group': 'प्राथमिकताएँ',
      'profile_preferences_description': 'इस डिवाइस की भाषा सेटिंग्स।',
      'profile_support_group': 'सहायता',
      'profile_support_group_description': 'साइबर उदय टीम से सहायता।',
      'profile_language': 'भाषा',
      'profile_language_subtitle':
          'साइबर उदय में इस्तेमाल की जाने वाली भाषा चुनें।',
      'profile_help': 'सहायता और समर्थन',
      'profile_help_subtitle': 'साइबर उदय टीम से संपर्क करें।',
      'profile_citizen_fallback': 'साइबर उदय नागरिक',
      'profile_signout_title': 'साइबर उदय से साइन आउट करें?',
      'profile_signout_description':
          'जब आप तैयार हों तब फिर से साइन इन कर सकते हैं।',
      'profile_signout_confirm': 'साइन आउट करें',
      'profile_sign_out': 'साइन आउट',
      'cancel': 'रद्द करें',
      'developers': 'डेवलपर्स',
      'dashboard_action_scanner': 'खतरा स्कैनर',
      'dashboard_action_scanner_description':
          'संदिग्ध लिंक या संदेश की जाँच करें।',
      'dashboard_action_report': 'साइबर अपराध रिपोर्ट करें',
      'dashboard_action_report_description':
          'मार्गदर्शित सहायता के साथ रिपोर्ट शुरू करें।',
      'dashboard_action_emergency': 'आपातकालीन सहायता',
      'dashboard_action_emergency_description':
          'आपातकालीन संपर्कों तक जल्दी पहुँचें।',
      'dashboard_action_bank': 'बैंक कनेक्ट करें',
      'dashboard_action_bank_description':
          'सहायता के लिए अनुमति अनुरोध सहेजें।',
      'bank_security': 'बैंक सुरक्षा',
      'bank_security_title': 'बैंक सुरक्षा',
      'bank_security_intro':
          'साइबर उदय के साथ अपनी बैंक सहायता अनुमतियों को सुरक्षित रूप से प्रबंधित करें।',
      'bank_security_loading': 'आपकी सहेजी गई सहायता अनुमति जाँची जा रही है...',
      'bank_security_permission_title': 'सहायता अनुमति अनुरोध सहेजा गया',
      'bank_security_permission_none':
          'अभी तक कोई सहायता अनुमति अनुरोध नहीं है',
      'bank_security_permission_description':
          'यह साइबर उदय सहायता के लिए आपके अनुरोध को दर्ज करता है। यह बैंक कनेक्ट नहीं करता और बैंक क्रेडेंशियल एकत्र नहीं करता।',
      'bank_security_credentials_note':
          'साइबर उदय यहाँ बैंक क्रेडेंशियल एकत्र नहीं करता। किसी भी भविष्य के बैंक कनेक्शन के लिए अधिकृत एकीकरण और आपकी सहमति आवश्यक होगी।',
      'bank_security_request': 'सहायता का अनुरोध करें',
      'bank_security_update': 'अनुरोध अपडेट करें',
      'bank_security_load_failed': 'अनुमति की स्थिति उपलब्ध नहीं है',
      'bank_security_load_failed_description':
          'हम आपकी सहेजी गई सहायता अनुमति पढ़ नहीं सके। आप नया अनुरोध भेजकर फिर कोशिश कर सकते हैं।',
      'bank_security_permission_saved_message':
          'आपका बैंक सहायता अनुमति अनुरोध सहेजा गया।',
      'bank_security_permission_failed':
          'बैंक सहायता अनुमति अनुरोध सहेजा नहीं जा सका।',
      'dashboard_bank_security_description':
          'बैंक क्रेडेंशियल साझा किए बिना बैंक सहायता अनुमतियाँ देखें।',
      'dashboard_bank_security_view': 'बैंक सुरक्षा देखें',
      'dashboard_latest_news_title': 'ताज़ा साइबर समाचार',
      'dashboard_latest_news_subtitle':
          'वर्तमान तकनीक और सुरक्षा लिंक से जागरूक रहें।',
      'dashboard_view_all': 'सभी देखें',
      'dashboard_latest_news_loading': 'ताज़ा समाचार लोड हो रहे हैं...',
      'dashboard_latest_news_error': 'ताज़ा समाचार अभी उपलब्ध नहीं हैं।',
      'dashboard_latest_news_empty': 'अभी कोई ताज़ा समाचार उपलब्ध नहीं है।',
      'dashboard_latest_news_open_failed': 'समाचार लिंक नहीं खुल सका।',
      'retry': 'फिर कोशिश करें',
      'language_english': 'अंग्रेज़ी',
      'language_hindi': 'हिन्दी',
      'language_marathi': 'मराठी',
      'admin': 'एडमिन',
      'brand_tagline': 'आपका डिजिटल सुरक्षा घर।',
      'scanner_page_title':
          'संदिग्ध लिंक, ऐप और स्क्रीनशॉट के लिए खतरा स्कैनर।',
      'scanner_page_subtitle':
          'सुरक्षा समीक्षा के लिए वेबसाइट, ऐप लिंक या चित्र प्रमाण भेजें।',
      'scanner_submit_title': 'संदिग्ध सामग्री भेजें',
      'scanner_submit_subtitle':
          'संदिग्ध लिंक या प्रमाण जोड़ें ताकि वर्चुअल टीम जोखिम की जाँच कर सके।',
      'scanner_link_label': 'वेबसाइट या फ़िशिंग लिंक',
      'scanner_app_label': 'ऐप नाम या APK स्रोत लिंक',
      'scanner_note_label': 'चित्र या प्रमाण नोट',
      'scanner_upload': 'चित्र अपलोड करें',
      'scanner_submit': 'वर्चुअल टीम को भेजें',
      'scanner_fill_one': 'कृपया कम से कम एक फ़ील्ड भरें।',
      'scanner_submitted': 'खतरे की जाँच वर्चुअल टीम को भेज दी गई है।',
      'scanner_picker_opening': 'चित्र चयनकर्ता खुल रहा है...',
      'report_page_title': 'साइबर अपराध पीड़ितों के लिए AI रिपोर्ट तैयार करना।',
      'report_page_subtitle':
          'घटना, प्रमाण और समयरेखा को रिपोर्ट में व्यवस्थित करने के लिए मार्गदर्शित सहायता लें।',
      'report_workflow_title': 'AI सहायता वाला वर्कफ़्लो',
      'report_workflow_subtitle':
          'जो हुआ उसे बोलें या लिखें। साइबर उदय तथ्यों को औपचारिक रिपोर्ट में व्यवस्थित करने में मदद करता है।',
      'report_description_label': 'हमले या धोखाधड़ी का विवरण दें',
      'report_timeline_label': 'पीड़ित का विवरण और समयरेखा',
      'report_evidence_label': 'प्रमाण लिंक, स्क्रीनशॉट, UPI ID',
      'report_chat_ai': 'AI से चैट करें',
      'report_generate_pdf': 'PDF रिपोर्ट बनाएँ',
      'report_destination_title': 'रिपोर्ट का गंतव्य',
      'report_destination_subtitle':
          'चुनें कि रिपोर्ट साइबर उदय टीम या साइबर सेल को भेजनी है।',
      'report_submit_team': 'हमारी टीम को भेजें',
      'report_submit_cell': 'साइबर सेल को भेजें',
      'report_describe_first': 'कृपया हमले का विवरण दें।',
      'report_submitted': 'रिपोर्ट {destination} को सफलतापूर्वक भेज दी गई।',
      'report_fill_first': 'पहले विवरण भरें या रिपोर्ट भेजें।',
      'emergency_page_title': 'आपातकालीन हेल्पलाइन',
      'emergency_page_subtitle':
          'अधिकारी और आपातकालीन सेवाएँ तुरंत उपलब्ध। कॉल करने के लिए एक टैप।',
      'call_label': 'कॉल: {number}',
      'news_page_title':
          'हाल के साइबर अपराध समाचार और नागरिक अपडेट से जागरूक रहें।',
      'news_page_subtitle':
          'सत्यापित समाचार और समीक्षा के लिए टीम को भेजे गए नागरिक अपडेट पढ़ें।',
      'news_recent_title': 'हाल के समाचार',
      'news_recent_subtitle':
          'साइबर धोखाधड़ी, नकली लॉटरी और फ़िशिंग अलर्ट की दैनिक जानकारी।',
      'news_empty': 'अभी कोई समाचार प्रकाशित नहीं है।',
      'news_hacker_title': 'Hacker News',
      'news_hacker_subtitle': 'Hacker News से तकनीक और सुरक्षा लिंक।',
      'news_hacker_error': 'अभी Hacker News लोड नहीं हो सका।',
      'news_hacker_empty': 'कोई Hacker News कहानी उपलब्ध नहीं है।',
      'news_refresh': 'रिफ्रेश करें',
      'news_create_title': 'नया समाचार बनाएँ',
      'news_create_subtitle':
          'सार्वजनिक करने से पहले स्थानीय घोटाले की चेतावनी या संदिग्ध पैटर्न टीम को भेजें।',
      'news_headline_label': 'शीर्षक या धोखाधड़ी पैटर्न',
      'news_content_label': 'क्या हुआ और कहाँ',
      'news_submit_team': 'टीम को भेजें',
      'news_fill_all': 'कृपया सभी फ़ील्ड भरें।',
      'news_submitted':
          'समाचार समीक्षा के लिए भेज दिया गया है। एडमिन की मंज़ूरी के बाद दिखाई देगा।',
      'news_invalid_link': 'समाचार लिंक अमान्य है।',
      'news_open_failed': 'समाचार लिंक नहीं खुल सका।',
      'scan_page_title': 'खतरों के लिए अपने मोबाइल और कंप्यूटर को स्कैन करें।',
      'scan_page_subtitle':
          'मोबाइल और कंप्यूटर खतरों के लिए मार्गदर्शित सुरक्षा जाँच का उपयोग करें।',
      'scan_mobile_title': 'मोबाइल स्कैन करें',
      'scan_mobile_subtitle':
          'जोखिम वाली अनुमतियाँ, नकली लोन ऐप, छिपे ओवरले और नोटिफिकेशन इंटरसेप्शन पैटर्न खोजें।',
      'scan_mobile_action': 'मोबाइल स्कैन शुरू करें',
      'scan_computer_title': 'कंप्यूटर स्कैन करें',
      'scan_computer_subtitle':
          'ब्राउज़र चेतावनियाँ, रिमोट एक्सेस, फ़िशिंग निशान और संदिग्ध डाउनलोड जाँचें।',
      'scan_computer_action': 'कंप्यूटर स्कैन शुरू करें',
      'emergency_police': 'पुलिस',
      'emergency_ambulance': 'एम्बुलेंस',
      'emergency_fire': 'अग्निशमन सेवा',
      'emergency_cyber_cell': 'साइबर सेल',
      'emergency_women': 'महिला हेल्पलाइन',
      'emergency_child': 'बाल हेल्पलाइन',
      'rewards_page_title':
          'ऑपरेटिव स्थिति, सिक्के, प्रीमियम सहायता और दावा प्रक्रिया।',
      'rewards_page_subtitle':
          'सुरक्षा आदतें पूरी करके अंक कमाएँ और सहायता अनलॉक करें।',
      'rewards_status_title': 'ऑपरेटिव स्थिति',
      'rewards_status_subtitle':
          'अपना बैलेंस देखें, अंक क्लेम करें और मोबाइल चुनौती पूरी करें।',
      'rewards_balance': 'बैलेंस',
      'rewards_points': 'अंक दावा',
      'rewards_challenge': 'मोबाइल चुनौती',
      'rewards_ready': 'तैयार',
      'rewards_premium_title': 'प्रीमियम सुविधाएँ',
      'rewards_premium_subtitle':
          'प्रीमियम से टीम सहायता, तेज़ केस प्रक्रिया और लगभग निरंतर उपलब्धता मिलती है।',
      'rewards_team_support': 'आपका केस हल करने में हमारी टीम की सहायता',
      'rewards_guidance': '24/7 समाधान मार्गदर्शन',
      'rewards_escalation': 'उच्च जोखिम वाली रिपोर्ट के लिए प्राथमिकता सहायता',
      'rewards_claim': 'अंक क्लेम करें',
      'contact_options_title': 'संपर्क विकल्प',
      'contact_page_title': 'साइबर उदय टीम और सहायता लाइनों से जुड़ें।',
      'contact_page_subtitle':
          'सहायता कॉल, सहयोग, निवेश या कंपनी साझेदारी के लिए इस पेज का उपयोग करें।',
      'contact_options_subtitle':
          'टीम से बात करें, सहयोग शुरू करें या सीधे सहायता माँगें।',
      'contact_call_team': 'हमारी टीम को कॉल करें',
      'contact_collaborate': 'हमसे सहयोग करें',
      'contact_investment': 'निवेश सहायता',
      'contact_help': 'मेरी मदद करें',
      'contact_company': 'कंपनी सहयोग',
      'contact_helpline_title': 'हेल्पलाइन 24/7',
      'contact_helpline_subtitle':
          'भविष्य में आपातकालीन स्थिति के अनुसार सही सेवा या साइबर उदय टीम से जोड़ा जा सकेगा।',
      'contact_fire': 'फायर वाहन',
      'contact_team': 'साइबर उदय टीम',
      'developers_header': 'इंजीनियरिंग टीम से मिलें',
      'developers_description':
          'साइबर सुरक्षा, Flutter, AI, बैकएंड आर्किटेक्चर और यूज़र अनुभव की केंद्रित टीम।',
      'developers_link_pending': 'यह टीम लिंक बाद में जोड़ा जाएगा।',
      'link_open_failed': 'लिंक नहीं खुल सका।',
      'sessions_page_title': 'विशेषज्ञ परामर्श',
      'sessions_page_subtitle':
          'सत्यापित डिजिटल सुरक्षा पेशेवरों से व्यक्तिगत मार्गदर्शन पाएँ।',
      'sessions_all': 'सभी',
      'sessions_security': 'सुरक्षा',
      'sessions_legal': 'कानूनी',
      'sessions_mental_health': 'मानसिक स्वास्थ्य',
      'sessions_online': 'ऑनलाइन',
      'sessions_next_available': 'अगली उपलब्धता',
      'sessions_per_30_minutes': '30 मिनट के लिए',
      'sessions_requested': 'सत्र का अनुरोध भेजा गया',
      'sessions_request_sent':
          '{name} के साथ सत्र का आपका अनुरोध भेज दिया गया है। हमारी टीम 15 मिनट में संपर्क करेगी।',
      'sessions_got_it': 'समझ गया',
      'sessions_book': 'तुरंत सत्र बुक करें',
      'assistant_download_report': 'तैयार रिपोर्ट डाउनलोड करें',
      'assistant_voice_title': 'साइबर वॉइस इंटरव्यू',
      'assistant_voice_subtitle': 'आपके उत्तर से रिपोर्ट तैयार होगी',
      'assistant_listening': 'सुन रहे हैं...',
      'assistant_type_or_mic': 'लिखें या माइक्रोफ़ोन का उपयोग करें...',
      'assistant_initial_greeting':
          'नमस्ते! मैं आपका साइबर बॉडीगार्ड हूँ। घटना की रिपोर्ट करने के लिए बताएं कि क्या हुआ।',
      'assistant_unavailable': 'मैं इसे संसाधित नहीं कर सका।',
      'assistant_connection_error':
          'कनेक्शन में समस्या आई। कृपया दोबारा बताएं।',
      'splash_preparing': 'साइबर उदय तैयार हो रहा है',
      'splash_workspace': 'आपका कार्यक्षेत्र तैयार हो रहा है',
      'brand_bodyguard': 'आपका डिजिटल बॉडीगार्ड',
    },
    'mr': {
      'dashboard': 'डॅशबोर्ड',
      'report_crime': 'गुन्हा नोंदवा',
      'threat_scanner': 'धोका स्कॅनर',
      'cyber_news': 'सायबर बातम्या',
      'rewards': 'बक्षीस',
      'contact_us': 'संपर्क साधा',
      'sessions': '1:1 सत्र',
      'scan_system': 'सिस्टम स्कॅन करा',
      'emergency': 'आणीबाणी',
      'nav_protection': 'सुरक्षा',
      'nav_support': 'मदत',
      'nav_about': 'परिचय',
      'assistant_open': 'सायबर उदय सहाय्यक उघडा',
      'assistant_close': 'सायबर उदय सहाय्यक बंद करा',
      'assistant_title': 'सायबर उदय सहाय्यक',
      'assistant_subtitle': 'तुमचा डिजिटल सुरक्षा साथीदार',
      'assistant_prompt': 'तुम्हाला सुरक्षित राहण्यास मी कशी मदत करू?',
      'assistant_check_link': 'संशयास्पद लिंक तपासा',
      'assistant_scammed': 'माझी फसवणूक झाली असे वाटते',
      'assistant_bank_security': 'बँक सुरक्षा',
      'assistant_phone_hacked': 'माझा फोन हॅक झाला असावा',
      'assistant_emergency': 'आपत्कालीन मदत',
      'assistant_report_crime': 'सायबर गुन्हा रिपोर्ट करा',
      'assistant_ask': 'सायबर उदयला विचारा',
      'welcome': 'तुमचे स्वागत आहे',
      'hacked_btn': 'मी हॅक झालो आहे',
      'hacked_title': 'आणीबाणी: खाते उल्लंघन आढळले',
      'hacked_desc':
          'बँक गोठवणे सुरू करणे, वैयक्तिक डेटा सुरक्षित करणे आणि अधिकाऱ्यांना सूचित करणे...',
      'freeze_bank': 'माझी बँक गोठवा',
      'connect_bank': 'बँक कनेक्ट करा',
      'total_reports': 'एकूण अहवाल',
      'threats_blocked': 'धोके रोखले',
      'hero_title':
          'जेव्हा सामान्य लोकांना फसवणुकीचे लक्ष्य केले जाते तेव्हा डिजिटल युद्ध सुरू होते.',
      'dashboard_greeting': 'तुमचे स्वागत आहे',
      'dashboard_intro': 'तुमची डिजिटल सुरक्षा, एका नजरेत.',
      'dashboard_protection_title': 'तुमच्या सुरक्षेचा आढावा',
      'dashboard_protection_description':
          'स्कॅन, रिपोर्ट किंवा मदतीची विनंती केल्यानंतर तुमची वैयक्तिक गतिविधी येथे दिसेल.',
      'dashboard_protection_status': 'मदतीसाठी तयार',
      'dashboard_quick_actions': 'आज तुम्हाला कशाची गरज आहे?',
      'dashboard_quick_actions_subtitle': 'तुमच्या परिस्थितीनुसार कृती निवडा.',
      'dashboard_activity_title': 'अलीकडील गतिविधी',
      'dashboard_activity_subtitle':
          'तुमच्या सुरक्षा कृतींचा एकाच ठिकाणी मागोवा ठेवा.',
      'dashboard_activity_empty':
          'अजून वैयक्तिक गतिविधी दिसत नाही. सुरुवात करण्यासाठी लिंक स्कॅन करा किंवा रिपोर्ट पाठवा.',
      'dashboard_services_title': 'सायबर उदयच्या इतर सेवा',
      'dashboard_services_subtitle': 'गरजेनुसार मदत आणि सुरक्षा सेवा वापरा.',
      'dashboard_emergency_description':
          'तुमचे खाते किंवा डिव्हाइस धोक्यात असल्यास आपत्कालीन विनंती पाठवण्यापूर्वी पुढील पाऊल पाहा.',
      'dashboard_get_help': 'आपत्कालीन मदत पाहा',
      'dashboard_emergency_logged':
          'तुमची आपत्कालीन विनंती मदतीसाठी जतन केली आहे.',
      'dashboard_bank_connecting':
          'तुमची बँक मदत परवानगी विनंती जतन करत आहोत...',
      'dashboard_bank_connected':
          'बँक मदत परवानगी विनंती जतन केली. बँक क्रेडेन्शियल्स घेतलेली नाहीत.',
      'dashboard_action_failed':
          'ही कृती पूर्ण करता आली नाही. कृपया पुन्हा प्रयत्न करा.',
      'profile_title': 'प्रोफाइल',
      'profile_back': 'मागे जा',
      'profile_header_title': 'प्रोफाइल',
      'profile_header_subtitle':
          'तुमचे सायबर उदय खाते आणि प्राधान्ये व्यवस्थापित करा.',
      'profile_account_label': 'सायबर उदय खाते',
      'profile_avatar_label': 'खाते प्रोफाइल प्रतिमा',
      'profile_account_group': 'खाते',
      'profile_account_group_description': 'तुमच्या अनुभवासाठी प्राधान्ये.',
      'profile_preferences_group': 'प्राधान्ये',
      'profile_preferences_description': 'या डिव्हाइससाठी भाषा सेटिंग्ज.',
      'profile_support_group': 'मदत',
      'profile_support_group_description': 'सायबर उदय टीमकडून मदत.',
      'profile_language': 'भाषा',
      'profile_language_subtitle': 'सायबर उदयमध्ये वापरली जाणारी भाषा निवडा.',
      'profile_help': 'मदत आणि समर्थन',
      'profile_help_subtitle': 'सायबर उदय टीमशी संपर्क साधा.',
      'profile_citizen_fallback': 'सायबर उदय नागरिक',
      'profile_signout_title': 'सायबर उदयमधून साइन आउट करायचे?',
      'profile_signout_description':
          'तयार झाल्यावर तुम्ही पुन्हा साइन इन करू शकता.',
      'profile_signout_confirm': 'साइन आउट करा',
      'profile_sign_out': 'साइन आउट',
      'cancel': 'रद्द करा',
      'developers': 'डेव्हलपर्स',
      'dashboard_action_scanner': 'धोका स्कॅनर',
      'dashboard_action_scanner_description':
          'संशयास्पद लिंक किंवा संदेश तपासा.',
      'dashboard_action_report': 'सायबर गुन्हा रिपोर्ट करा',
      'dashboard_action_report_description':
          'मार्गदर्शित मदतीने रिपोर्ट सुरू करा.',
      'dashboard_action_emergency': 'आपत्कालीन मदत',
      'dashboard_action_emergency_description':
          'आपत्कालीन संपर्कांपर्यंत पटकन पोहोचा.',
      'dashboard_action_bank': 'बँक कनेक्ट करा',
      'dashboard_action_bank_description': 'मदतीसाठी परवानगी विनंती जतन करा.',
      'bank_security': 'बँक सुरक्षा',
      'bank_security_title': 'बँक सुरक्षा',
      'bank_security_intro':
          'सायबर उदयसह तुमच्या बँक मदत परवानग्या सुरक्षितपणे व्यवस्थापित करा.',
      'bank_security_loading': 'तुमची जतन केलेली मदत परवानगी तपासत आहोत...',
      'bank_security_permission_title': 'मदत परवानगी विनंती जतन केली',
      'bank_security_permission_none': 'अजून कोणतीही मदत परवानगी विनंती नाही',
      'bank_security_permission_description':
          'यामुळे सायबर उदय मदतीसाठी तुमची विनंती नोंदवली जाते. यामुळे बँक कनेक्ट होत नाही किंवा बँक क्रेडेन्शियल्स घेतली जात नाहीत.',
      'bank_security_credentials_note':
          'सायबर उदय येथे बँक क्रेडेन्शियल्स घेत नाही. भविष्यातील कोणत्याही बँक कनेक्शनसाठी अधिकृत एकत्रीकरण आणि तुमची संमती आवश्यक असेल.',
      'bank_security_request': 'मदतीची विनंती करा',
      'bank_security_update': 'विनंती अपडेट करा',
      'bank_security_load_failed': 'परवानगीची स्थिती उपलब्ध नाही',
      'bank_security_load_failed_description':
          'तुमची जतन केलेली मदत परवानगी वाचता आली नाही. नवीन विनंती पाठवून पुन्हा प्रयत्न करा.',
      'bank_security_permission_saved_message':
          'तुमची बँक मदत परवानगी विनंती जतन केली.',
      'bank_security_permission_failed':
          'बँक मदत परवानगी विनंती जतन करता आली नाही.',
      'dashboard_bank_security_description':
          'बँक क्रेडेन्शियल्स शेअर न करता बँक मदत परवानग्या पाहा.',
      'dashboard_bank_security_view': 'बँक सुरक्षा पाहा',
      'dashboard_latest_news_title': 'ताज्या सायबर बातम्या',
      'dashboard_latest_news_subtitle':
          'सध्याच्या तंत्रज्ञान आणि सुरक्षा लिंक्ससह जागरूक रहा.',
      'dashboard_view_all': 'सर्व पहा',
      'dashboard_latest_news_loading': 'ताज्या बातम्या लोड होत आहेत...',
      'dashboard_latest_news_error': 'ताज्या बातम्या सध्या उपलब्ध नाहीत.',
      'dashboard_latest_news_empty':
          'सध्या कोणत्याही ताज्या बातम्या उपलब्ध नाहीत.',
      'dashboard_latest_news_open_failed': 'बातमी लिंक उघडता आली नाही.',
      'retry': 'पुन्हा प्रयत्न करा',
      'language_english': 'इंग्रजी',
      'language_hindi': 'हिंदी',
      'language_marathi': 'मराठी',
      'admin': 'अॅडमिन',
      'brand_tagline': 'तुमचे डिजिटल सुरक्षा घर.',
      'scanner_page_title':
          'संशयास्पद लिंक, अॅप्स आणि स्क्रीनशॉटसाठी धोका स्कॅनर.',
      'scanner_page_subtitle':
          'सुरक्षा तपासणीसाठी वेबसाइट, अॅप लिंक किंवा चित्र पुरावा पाठवा.',
      'scanner_submit_title': 'संशयास्पद सामग्री पाठवा',
      'scanner_submit_subtitle':
          'संशयास्पद लिंक किंवा पुरावा जोडा, म्हणजे व्हर्च्युअल टीम धोका तपासू शकेल.',
      'scanner_link_label': 'वेबसाइट किंवा फिशिंग लिंक',
      'scanner_app_label': 'अॅपचे नाव किंवा APK स्रोत लिंक',
      'scanner_note_label': 'चित्र किंवा पुरावा नोंद',
      'scanner_upload': 'चित्र अपलोड करा',
      'scanner_submit': 'व्हर्च्युअल टीमला पाठवा',
      'scanner_fill_one': 'कृपया किमान एक फील्ड भरा.',
      'scanner_submitted': 'धोका तपासणी व्हर्च्युअल टीमला पाठवली आहे.',
      'scanner_picker_opening': 'चित्र निवडक उघडत आहे...',
      'report_page_title':
          'सायबर गुन्ह्यांच्या पीडितांसाठी AI रिपोर्ट तयार करणे.',
      'report_page_subtitle':
          'घटना, पुरावे आणि वेळरेषा रिपोर्टमध्ये मांडण्यासाठी मार्गदर्शित मदत वापरा.',
      'report_workflow_title': 'AI सहाय्यित वर्कफ्लो',
      'report_workflow_subtitle':
          'काय झाले ते बोला किंवा लिहा. सायबर उदय तथ्ये औपचारिक रिपोर्टमध्ये मांडण्यास मदत करतो.',
      'report_description_label': 'हल्ला किंवा फसवणूक वर्णन करा',
      'report_timeline_label': 'पीडिताचा तपशील आणि वेळरेषा',
      'report_evidence_label': 'पुरावा लिंक, स्क्रीनशॉट, UPI ID',
      'report_chat_ai': 'AI शी चॅट करा',
      'report_generate_pdf': 'PDF रिपोर्ट तयार करा',
      'report_destination_title': 'रिपोर्टचे गंतव्य',
      'report_destination_subtitle':
          'रिपोर्ट सायबर उदय टीमकडे किंवा सायबर सेलला पाठवायचा ते निवडा.',
      'report_submit_team': 'आमच्या टीमला पाठवा',
      'report_submit_cell': 'सायबर सेलला पाठवा',
      'report_describe_first': 'कृपया हल्ल्याचे वर्णन करा.',
      'report_submitted': 'रिपोर्ट {destination} कडे यशस्वीपणे पाठवला.',
      'report_fill_first': 'आधी तपशील भरा किंवा रिपोर्ट पाठवा.',
      'emergency_page_title': 'आपत्कालीन हेल्पलाइन',
      'emergency_page_subtitle':
          'अधिकारी आणि आपत्कालीन सेवा त्वरित उपलब्ध. कॉल करण्यासाठी एक टॅप.',
      'call_label': 'कॉल: {number}',
      'news_page_title':
          'अलीकडील सायबर गुन्हे बातम्या आणि नागरिक अपडेट्ससह जागरूक रहा.',
      'news_page_subtitle':
          'सत्यापित बातम्या आणि टीमकडे पाठवलेले नागरिक जागरूकता अपडेट्स वाचा.',
      'news_recent_title': 'अलीकडील बातम्या',
      'news_recent_subtitle':
          'सायबर फसवणूक, बनावट लॉटरी आणि फिशिंग अलर्टची दैनिक माहिती.',
      'news_empty': 'अजून कोणतीही बातमी प्रकाशित नाही.',
      'news_hacker_title': 'Hacker News',
      'news_hacker_subtitle': 'Hacker News मधील तंत्रज्ञान आणि सुरक्षा लिंक.',
      'news_hacker_error': 'आत्ता Hacker News लोड करता आले नाही.',
      'news_hacker_empty': 'कोणतीही Hacker News कथा उपलब्ध नाही.',
      'news_refresh': 'रिफ्रेश करा',
      'news_create_title': 'नवीन बातमी तयार करा',
      'news_create_subtitle':
          'सार्वजनिक करण्यापूर्वी स्थानिक घोटाळ्याचा इशारा किंवा संशयास्पद पॅटर्न टीमला पाठवा.',
      'news_headline_label': 'शीर्षक किंवा फसवणूक पॅटर्न',
      'news_content_label': 'काय झाले आणि कुठे',
      'news_submit_team': 'टीमला पाठवा',
      'news_fill_all': 'कृपया सर्व फील्ड भरा.',
      'news_submitted':
          'बातमी तपासणीसाठी पाठवली आहे. अॅडमिनच्या मंजुरीनंतर दिसेल.',
      'news_invalid_link': 'बातमी लिंक अवैध आहे.',
      'news_open_failed': 'बातमी लिंक उघडता आली नाही.',
      'scan_page_title': 'धोक्यांसाठी तुमचा मोबाइल आणि संगणक स्कॅन करा.',
      'scan_page_subtitle':
          'मोबाइल आणि संगणक धोक्यांसाठी मार्गदर्शित सुरक्षा तपासणी वापरा.',
      'scan_mobile_title': 'मोबाइल स्कॅन करा',
      'scan_mobile_subtitle':
          'धोकादायक परवानग्या, बनावट लोन अॅप्स, लपवलेले ओव्हरले आणि नोटिफिकेशन इंटरसेप्शन पॅटर्न शोधा.',
      'scan_mobile_action': 'मोबाइल स्कॅन सुरू करा',
      'scan_computer_title': 'संगणक स्कॅन करा',
      'scan_computer_subtitle':
          'ब्राउझर इशारे, रिमोट अॅक्सेस, फिशिंग खुणा आणि संशयास्पद डाउनलोड तपासा.',
      'scan_computer_action': 'संगणक स्कॅन सुरू करा',
      'emergency_police': 'पोलीस',
      'emergency_ambulance': 'रुग्णवाहिका',
      'emergency_fire': 'अग्निशमन दल',
      'emergency_cyber_cell': 'सायबर सेल',
      'emergency_women': 'महिला हेल्पलाइन',
      'emergency_child': 'बाल हेल्पलाइन',
      'rewards_page_title':
          'ऑपरेटिव स्थिती, नाणी, प्रीमियम मदत आणि क्लेम प्रक्रिया.',
      'rewards_page_subtitle':
          'सुरक्षा सवयी पूर्ण करून गुण मिळवा आणि मदत अनलॉक करा.',
      'rewards_status_title': 'ऑपरेटिव स्थिती',
      'rewards_status_subtitle':
          'बॅलन्स पाहा, गुण क्लेम करा आणि मोबाइल आव्हान पूर्ण करा.',
      'rewards_balance': 'बॅलन्स',
      'rewards_points': 'गुण क्लेम',
      'rewards_challenge': 'मोबाइल आव्हान',
      'rewards_ready': 'तयार',
      'rewards_premium_title': 'प्रीमियम सुविधा',
      'rewards_premium_subtitle':
          'प्रीमियममुळे थेट टीम मदत, जलद केस प्रक्रिया आणि जवळपास सतत उपलब्धता मिळते.',
      'rewards_team_support': 'तुमचा केस सोडवण्यासाठी आमच्या टीमची मदत',
      'rewards_guidance': '24/7 उपाय मार्गदर्शन',
      'rewards_escalation': 'उच्च-धोका रिपोर्टसाठी प्राधान्य एस्कलेशन',
      'rewards_claim': 'गुण क्लेम करा',
      'contact_options_title': 'संपर्क पर्याय',
      'contact_page_title': 'सायबर उदय टीम आणि मदत लाइन्सशी जोडा.',
      'contact_page_subtitle':
          'मदत कॉल, सहकार्य, गुंतवणूक किंवा कंपनी भागीदारीसाठी हे पृष्ठ वापरा.',
      'contact_options_subtitle':
          'टीमशी बोला, सहकार्य सुरू करा किंवा थेट मदत मागा.',
      'contact_call_team': 'आमच्या टीमला कॉल करा',
      'contact_collaborate': 'आमच्यासोबत सहकार्य करा',
      'contact_investment': 'गुंतवणूक मदत',
      'contact_help': 'मला मदत करा',
      'contact_company': 'कंपनी सहकार्य',
      'contact_helpline_title': 'हेल्पलाइन 24/7',
      'contact_helpline_subtitle':
          'भविष्यात आपत्कालीन संदर्भानुसार योग्य सेवा किंवा सायबर उदय टीमकडे मार्गदर्शन करता येईल.',
      'contact_fire': 'फायर वाहन',
      'contact_team': 'सायबर उदय टीम',
      'developers_header': 'इंजिनिअरिंग टीमला भेटा',
      'developers_description':
          'सायबर सुरक्षा, Flutter, AI, बॅकएंड आर्किटेक्चर आणि यूजर अनुभवातील केंद्रित टीम.',
      'developers_link_pending': 'ही टीम लिंक नंतर जोडली जाईल.',
      'link_open_failed': 'लिंक उघडता आली नाही.',
      'sessions_page_title': 'तज्ज्ञ सल्लामसलत',
      'sessions_page_subtitle':
          'सत्यापित डिजिटल सुरक्षा व्यावसायिकांकडून वैयक्तिक मार्गदर्शन मिळवा.',
      'sessions_all': 'सर्व',
      'sessions_security': 'सुरक्षा',
      'sessions_legal': 'कायदेशीर',
      'sessions_mental_health': 'मानसिक आरोग्य',
      'sessions_online': 'ऑनलाइन',
      'sessions_next_available': 'पुढील उपलब्धता',
      'sessions_per_30_minutes': '30 मिनिटांसाठी',
      'sessions_requested': 'सत्राची विनंती पाठवली',
      'sessions_request_sent':
          '{name} सोबत सत्राची तुमची विनंती पाठवली आहे. आमची टीम 15 मिनिटांत संपर्क करेल.',
      'sessions_got_it': 'समजले',
      'sessions_book': 'त्वरित सत्र बुक करा',
      'assistant_download_report': 'तयार रिपोर्ट डाउनलोड करा',
      'assistant_voice_title': 'सायबर व्हॉइस मुलाखत',
      'assistant_voice_subtitle': 'तुमच्या उत्तरांमधून रिपोर्ट तयार होईल',
      'assistant_listening': 'ऐकत आहे...',
      'assistant_type_or_mic': 'टाइप करा किंवा मायक्रोफोन वापरा...',
      'assistant_initial_greeting':
          'नमस्कार! मी तुमचा सायबर बॉडीगार्ड आहे. घटनेचा रिपोर्ट करण्यासाठी काय झाले ते सांगा.',
      'assistant_unavailable': 'मी ते प्रक्रिया करू शकलो नाही.',
      'assistant_connection_error':
          'कनेक्शनमध्ये अडचण आली. कृपया पुन्हा सांगा.',
      'splash_preparing': 'सायबर उदय तयार होत आहे',
      'splash_workspace': 'तुमचे कार्यक्षेत्र तयार होत आहे',
      'brand_bodyguard': 'तुमचा डिजिटल बॉडीगार्ड',
    },
  };

  String translate(String key) {
    return _localizedValues[currentLocale.value]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  String translateWith(String key, Map<String, String> values) {
    var message = translate(key);
    values.forEach((placeholder, value) {
      message = message.replaceAll('{$placeholder}', value);
    });
    return message;
  }

  void setLocale(String locale) {
    currentLocale.value = locale;
  }
}
