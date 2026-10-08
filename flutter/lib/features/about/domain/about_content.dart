class FaqEntry {
  const FaqEntry({required this.question, required this.answer});

  final String question;
  final String answer;
}

abstract final class AboutContent {
  static const tagline = 'Next-Gen Memecoin App';
  static const description =
      'Nextel Connect is a secure trading platform that enables you to earn and '
      'manage your assets with interest. It is a full-featured crypto platform '
      'and much more.';
  static const highlights = <String>[
    'AI-powered trading and automated memecoin trading',
    'Real-time signals and analytics',
    'Minimal user effort required',
    'AI bots execute trades within 24 hours',
  ];
  static const developerCredit = 'Made with ♥ by Nextel Connect';
  static const supportLink = 'https://t.me/nextelconnect_support01';

  static const faqs = <FaqEntry>[
    FaqEntry(
      question: 'Is Nextel Connect secure?',
      answer:
          'Security is our top priority. Nextel Connect employs bank-grade security '
          'measures including multi-signature wallets, cold storage for funds, regular '
          'security audits, and advanced encryption to protect user assets and data.',
    ),
    FaqEntry(
      question: 'How does Nextel Connect select which memecoins to list?',
      answer:
          'We have a rigorous vetting process for listing memecoins that includes '
          'security audits, liquidity assessments, community engagement metrics, and '
          'development team evaluation. This ensures that we list only quality projects '
          'while still providing access to the newest and most promising memecoins.',
    ),
    FaqEntry(
      question: 'What is the minimum trading amount?',
      answer:
          'The minimum trading amount on Nextel Connect is 1 USD, which is paired '
          'to 1 USDT.',
    ),
    FaqEntry(
      question: 'Can I refer friends and family?',
      answer:
          'Yes, you can refer your friends with your username as your referral link. '
          'Your referral bonus is up to 5% of each trade and can be withdrawn at any time.',
    ),
    FaqEntry(
      question: 'How do I get started with Nextel Connect?',
      answer:
          'Getting started is simple. Click on Launch App, fill the registration form, '
          'and you are ready to start trading. The interface is designed for beginners '
          'and experienced traders.',
    ),
    FaqEntry(
      question: 'You still have questions you would like to ask?',
      answer:
          'Write to the support team, chat at the forum, or send a private message to an administrator.',
    ),
  ];
}
