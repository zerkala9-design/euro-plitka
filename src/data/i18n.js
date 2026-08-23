// Мультимова: uk (основна, корінь) та ru (/ru/).
export const LANGS = ['uk', 'ru'];

// Навігація для кожної мови. path — БЕЗ мовного префікса (uk),
// для ru додається /ru спереду автоматично.
export const navByLang = {
  uk: [
    { label: 'Головна', path: '/' },
    { label: 'Каталог', path: '/katalog/' },
    { label: 'LED дзеркала', path: '/led-dzerkalo/' },
    { label: 'Послуги', path: '/poslugy/' },
    { label: 'Про нас', path: '/pro-nas/' },
    { label: 'Статті', path: '/statti/' },
    { label: 'Доставка та оплата', path: '/dostavka/' },
    { label: 'Контакти', path: '/kontakty/' },
  ],
  ru: [
    { label: 'Главная', path: '/' },
    { label: 'Каталог', path: '/katalog/' },
    { label: 'LED зеркала', path: '/led-dzerkalo/' },
    { label: 'Услуги', path: '/poslugy/' },
    { label: 'О нас', path: '/pro-nas/' },
    { label: 'Статьи', path: '/statti/' },
    { label: 'Доставка и оплата', path: '/dostavka/' },
    { label: 'Контакты', path: '/kontakty/' },
  ],
};

// Загальні підписи інтерфейсу
export const ui = {
  uk: {
    menu: 'Головне меню',
    langLabel: 'Мова',
    footerRights: 'Усі права захищені',
    footerAbout: 'Виробник дзеркальної плитки та LED дзеркал у Києві',
    home: 'Головна',
  },
  ru: {
    menu: 'Главное меню',
    langLabel: 'Язык',
    footerRights: 'Все права защищены',
    footerAbout: 'Производитель зеркальной плитки и LED зеркал в Киеве',
    home: 'Главная',
  },
};

// Додати мовний префікс до шляху
export const withLang = (path, lang) => (lang === 'ru' ? '/ru' + path : path);
