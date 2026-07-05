export const site = {
  name: 'Євро Плитка',
  domain: 'euro-plitka.com.ua',
  phone: { tel: '+380995283637', display: '+38 (099) 528-36-37' },
  email: 'info-plitka@ukr.net',
  address: 'Київ',
  workingHours: 'Пн–Сб: 9:00–18:00',
  social: {
    instagram: 'https://www.instagram.com/euro_plitka/',
    facebook: '',
    telegram: 'https://t.me/europlitka',
  },
};

export const nav = [
  { label: 'Головна',           path: '/' },
  { label: 'Каталог',           path: '/katalog/' },
  { label: 'LED дзеркала',      path: '/led-dzerkalo/' },
  { label: 'Послуги',           path: '/poslugy/' },
  { label: 'Про нас',           path: '/pro-nas/' },
  { label: 'Доставка та оплата',path: '/dostavka/' },
  { label: 'Контакти',          path: '/kontakty/' },
];

export const tileCalcConfig = {
  silverPrice: 2120,
  colorPrice: 3270,
  trianglePrice: 1.5,
  facetsPrices: [0, 35, 55, 75, 95],
  extraPrice: 1.0,
  defaultPrice: 1.0,
  gridAuto: 400,
  gridRatio: { ideal: 1.35, max: 1.5 },
  tileMin: 200,
  tileMax: 600,
};

export const ledCalcConfig = {
  // Модель ціни: площа(м²) × perM2 + периметр(м) × perM.
  // Виведено з реальних цін (фонова: 2190 грн/м² + 960 грн/м периметру —
  // відтворює 600×600=3120, 1000×1000=6030, 2000×1000=10140 з похибкою <1%).
  // Фронтальна ~×1.2 (уточнити за прайсом).
  rates: {
    back:  { perM2: 2190, perM: 960 },
    front: { perM2: 2630, perM: 1150 },
  },
  priceRound: 10,
  lightColors: [
    { id: 'warm',    label: 'Тепле 3000K',     color: '#ffd580' },
    { id: 'neutral', label: 'Нейтральне 4000K', color: '#fff5cc' },
    { id: 'cold',    label: 'Холодне 6000K',    color: '#e8f4ff' },
  ],
  options: [
    { id: 'heat',   label: 'Підігрів', price: 400 },
    { id: 'sensor', label: 'Сенсор',   price: 300 },
  ],
  mounting: 500,
  delivery: 200,
  minSize: 300,
  maxSize: 2000,
  defaultW: 400,
  defaultH: 600,
};
