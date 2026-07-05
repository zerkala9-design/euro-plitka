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
  // Тарифи різні для форми (коло різати дорожче) та типу підсвітки.
  // Для кола: площа = діаметр² (з квадратного листа), периметр = π·D.
  rates: {
    rect: {
      // Фонова (Модель 1): 600×600=3120, 1000×1000=6030, 2000×1000=10140 (<1%)
      back:  { perM2: 2190, perM: 960 },
      // Фронтальна (Модель 4): 800×800=6880, 1200×800=9010, 1400×1000=11480 (<0.5%)
      front: { perM2: 2600, perM: 1630 },
    },
    circle: {
      // Фонова кругла (Модель 21): д600=3370, д1000=6450, д1200=8270 (<0.3%)
      back:  { perM2: 2130, perM: 1380 },
      // Фронтальна кругла (Модель 22): д700=5630, д1000=8820, д1400=13850 (<0.3%)
      front: { perM2: 2620, perM: 1980 },
    },
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
  mountingPercent: 0.35,  // монтаж = 35% від вартості дзеркала
  delivery: 1500,         // доставка — фіксовано 1500 грн
  minSize: 300,
  maxSize: 2000,
  defaultW: 400,
  defaultH: 600,
};
