class HelpFaqCategory {
  final int id;
  final String nameId;
  final String nameEn;
  final String icon;
  final int displayOrder;
  final int faqsCount;

  const HelpFaqCategory({
    required this.id,
    required this.nameId,
    required this.nameEn,
    required this.icon,
    this.displayOrder = 0,
    this.faqsCount = 0,
  });

  String localizedName(bool isId) => isId ? nameId : nameEn;

  factory HelpFaqCategory.fromJson(Map<String, dynamic> json) {
    return HelpFaqCategory(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      nameId: json['name_id']?.toString() ?? '',
      nameEn: json['name_en']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'help_outline',
      displayOrder: json['display_order'] is int
          ? json['display_order']
          : int.tryParse('${json['display_order']}') ?? 0,
      faqsCount: json['published_faqs_count'] is int
          ? json['published_faqs_count']
          : (json['faqs_count'] is int ? json['faqs_count'] : 0),
    );
  }
}

class HelpFaqItem {
  final int id;
  final int categoryId;
  final String questionId;
  final String answerId;
  final String questionEn;
  final String answerEn;
  final bool isPopular;
  final int helpfulCount;
  final int unhelpfulCount;

  const HelpFaqItem({
    required this.id,
    required this.categoryId,
    required this.questionId,
    required this.answerId,
    required this.questionEn,
    required this.answerEn,
    this.isPopular = false,
    this.helpfulCount = 0,
    this.unhelpfulCount = 0,
  });

  String localizedQuestion(bool isId) => isId ? questionId : questionEn;
  String localizedAnswer(bool isId) => isId ? answerId : answerEn;

  factory HelpFaqItem.fromJson(Map<String, dynamic> json) {
    return HelpFaqItem(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      categoryId: json['category_id'] is int
          ? json['category_id']
          : int.tryParse('${json['category_id']}') ?? 0,
      questionId: json['question_id']?.toString() ?? '',
      answerId: json['answer_id']?.toString() ?? '',
      questionEn: json['question_en']?.toString() ?? '',
      answerEn: json['answer_en']?.toString() ?? '',
      isPopular: json['is_popular'] == true || json['is_popular'] == 1,
      helpfulCount: json['helpful_count'] is int
          ? json['helpful_count']
          : int.tryParse('${json['helpful_count']}') ?? 0,
      unhelpfulCount: json['unhelpful_count'] is int
          ? json['unhelpful_count']
          : int.tryParse('${json['unhelpful_count']}') ?? 0,
    );
  }
}

class HelpSupportSettings {
  final String whatsappNumber;
  final String supportEmail;
  final String supportPhone;
  final String operatingHoursId;
  final String operatingHoursEn;
  final String waTemplateGeneral;
  final String waTemplateOrder;
  final String websiteUrl;
  final String instagramUrl;
  final String tiktokUrl;

  const HelpSupportSettings({
    required this.whatsappNumber,
    required this.supportEmail,
    required this.supportPhone,
    required this.operatingHoursId,
    required this.operatingHoursEn,
    required this.waTemplateGeneral,
    required this.waTemplateOrder,
    required this.websiteUrl,
    required this.instagramUrl,
    required this.tiktokUrl,
  });

  String localizedOperatingHours(bool isId) =>
      isId ? operatingHoursId : operatingHoursEn;

  factory HelpSupportSettings.fromJson(Map<String, dynamic> json) {
    final social = json['social_links'] is Map ? json['social_links'] : {};
    return HelpSupportSettings(
      whatsappNumber: json['whatsapp_number']?.toString() ?? '6281215883013',
      supportEmail:
          json['support_email']?.toString() ?? 'delitopiamarketing4@gmail.com',
      supportPhone: json['support_phone']?.toString() ?? '+62 812-1588-3013',
      operatingHoursId: json['operating_hours_id']?.toString() ??
          'Senin - Minggu (09:00 - 16:00 WIB)',
      operatingHoursEn: json['operating_hours_en']?.toString() ??
          'Monday - Sunday (09:00 AM - 04:00 PM)',
      waTemplateGeneral: json['wa_template_general']?.toString() ??
          'Halo CS Delitopia, saya ingin bertanya tentang layanan Delitopia.',
      waTemplateOrder: json['wa_template_order']?.toString() ?? '',
      websiteUrl:
          social['website']?.toString() ?? 'https://delitopiaindonesia.com',
      instagramUrl:
          social['instagram']?.toString() ?? 'https://www.instagram.com/sushikun.id',
      tiktokUrl:
          social['tiktok']?.toString() ?? 'https://www.tiktok.com/@sushikun.id',
    );
  }

  static const HelpSupportSettings defaultSettings = HelpSupportSettings(
    whatsappNumber: '6281215883013',
    supportEmail: 'delitopiamarketing4@gmail.com',
    supportPhone: '+62 812-1588-3013',
    operatingHoursId: 'Senin - Minggu (09:00 - 16:00 WIB)',
    operatingHoursEn: 'Monday - Sunday (09:00 AM - 04:00 PM)',
    waTemplateGeneral:
        'Halo CS Delitopia, saya ingin bertanya tentang layanan Delitopia.',
    waTemplateOrder: '',
    websiteUrl: 'https://delitopiaindonesia.com',
    instagramUrl: 'https://www.instagram.com/sushikun.id',
    tiktokUrl: 'https://www.tiktok.com/@sushikun.id',
  );
}
