class MyfinCity {
  const MyfinCity({required this.id, required this.name});

  final int id;
  final String name;
}

/// Областные центры Беларуси (myfin city_id).
const kDefaultMyfinCityId = 1;

const kMyfinCities = <MyfinCity>[
  MyfinCity(id: 1, name: 'Минск'),
  MyfinCity(id: 5, name: 'Брест'),
  MyfinCity(id: 2, name: 'Витебск'),
  MyfinCity(id: 3, name: 'Гомель'),
  MyfinCity(id: 4, name: 'Гродно'),
  MyfinCity(id: 6, name: 'Могилев'),
  MyfinCity(id: 26, name: 'Орша'),
];

MyfinCity myfinCityById(int id) {
  for (final city in kMyfinCities) {
    if (city.id == id) return city;
  }
  return kMyfinCities.first;
}
