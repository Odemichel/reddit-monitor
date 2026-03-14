const String redditUsername = 'aerox-befaster';

const String appPassword = 'aerox2026';

const List<String> subreddits = [
  //'Velo',
  'triathlon',
  'cycling',
  // 'bikefit',
  'IndoorCycling',
];

const Map<String, int> keywords = {
  'aero': 3,
  'bike': 1,

  // // Score 3 — AeroX est LA réponse directe
  // 'CdA': 3,
  // 'wind tunnel': 3,
  // 'aero position': 3,
  // 'position aero': 3,
  // 'test aero': 3,
  // 'measure aero': 3,
  // 'aero testing': 3,
  // 'dialed position': 3,
  // 'aero bars': 3,
  //
  // // Score 2 — contexte fort, AeroX apporte une réponse
  // 'get faster on the bike': 2,
  // 'faster on the bike': 2,
  // 'bike position': 2,
  // 'hold position': 2,
  // 'faster bike': 2,
  // 'rider position': 2,
  // 'wind resistance': 2,
  // 'aero bike': 2,
  // 'bike fit': 2,
  // 'TT position': 2,
  // 'triathlon bike': 2,
  // 'smart trainer': 2,
  // 'indoor trainer': 2,
  //
  // // Score 1 — signal faible, contexte pertinent
  // 'aero': 1,
  // 'faster': 1,
  // 'position': 1,
  // 'bike': 1,
  // 'training': 1,
  // 'drag': 1,
  // 'watts': 1,
  // 'home trainer': 1,
  // 'indoor': 1,
};

const Duration autoRefreshInterval = Duration(minutes: 60);
const int maxPostAgeDays = 7;
const int minCommentScore = 2;
