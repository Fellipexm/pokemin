import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:math';

void main() {
  runApp(MyApp());
}

final ThemeData customTheme = ThemeData(
  primaryColor: Colors.red,
  fontFamily: 'PokemonFont',
);

enum PokemonType {
  Normal,
  Fire,
  Water,
  Grass,
  Electric,
  // Adicione outros tipos aqui
}

class Pokemon {
  final int id;
  final String name;
  final int attack;
  final int defense;
  final int hp;
  final PokemonType type;
  double height = 0.0;
  double weight = 0.0;
  String azionePokedex = '';
  String foglielamaPokedex = '';
  List<String> types = [];
  Map<String, double> weaknesses = {};

  Pokemon({
    required this.id,
    required this.name,
    required this.attack,
    required this.defense,
    required this.hp,
    required this.type,
  });

  Future<void> fetchPokedexInfo() async {
    final speciesResponse =
        await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon-species/$id/'));
    if (speciesResponse.statusCode == 200) {
      final speciesJson = json.decode(speciesResponse.body);
      final pokedexEntries = speciesJson['flavor_text_entries'];
      final azioneEntry = pokedexEntries.firstWhere(
        (entry) =>
            entry['language']['name'] == 'it' &&
            entry['version']['name'] == 'azione',
        orElse: () => {'flavor_text': 'N/A'},
      );
      final foglielamaEntry = pokedexEntries.firstWhere(
        (entry) =>
            entry['language']['name'] == 'it' &&
            entry['version']['name'] == 'foglielama',
        orElse: () => {'flavor_text': 'N/A'},
      );
      azionePokedex = azioneEntry['flavor_text'];
      foglielamaPokedex = foglielamaEntry['flavor_text'];
    }
  }

  Future<void> fetchDetails() async {
    final response = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/$id/'));
    if (response.statusCode == 200) {
      final pokemonJson = json.decode(response.body);
      height = (pokemonJson['height'] as int) / 10.0;
      weight = (pokemonJson['weight'] as int) / 10.0;

      final typesList = pokemonJson['types'] as List<dynamic>;
      types = typesList.map((type) => type['type']['name'].toString()).toList();

      final abilitiesList = pokemonJson['abilities'] as List<dynamic>;
      for (var ability in abilitiesList) {
        final abilityName = ability['ability']['name'];
        final abilityResponse = await http.get(Uri.parse('https://pokeapi.co/api/v2/ability/$abilityName/'));
        if (abilityResponse.statusCode == 200) {
          final abilityJson = json.decode(abilityResponse.body);
          final weaknessesList = abilityJson['effect_entries'] as List<dynamic>;
          for (var entry in weaknessesList) {
            if (entry['language']['name'] == 'en' &&
                entry['effect'] == 'damages') {
              final List<dynamic> damageTypes = entry['short_effect'].split(' ').where((element) => element != 'damage').toList();
              for (var damageType in damageTypes) {
                final damageTypeName = damageType.replaceAll(RegExp(r'[,.]'), '');
                weaknesses[damageTypeName] = weaknesses[damageTypeName] ?? 0.0;
                weaknesses[damageTypeName] = weaknesses[damageTypeName]! + 0.5;
              }
            }
          }
        }
      }
    }
  }

  factory Pokemon.fromJson(Map<String, dynamic> json) {
    return Pokemon(
      id: json['id'],
      name: json['name'],
      attack: json['stats'][4]['base_stat'],
      defense: json['stats'][3]['base_stat'],
      hp: json['stats'][5]['base_stat'],
      type: PokemonType.Normal, // Defina o tipo apropriado aqui
    );
  }

  double calculateTypeAdvantage(Pokemon opponent) {
    if (type == PokemonType.Fire && opponent.type == PokemonType.Grass) {
      return 2.0;
    } else if (type == PokemonType.Grass && opponent.type == PokemonType.Fire) {
      return 0.5;
    }
    return 1.0;
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: customTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => PokemonSelectionScreen(),
        '/battle': (context) => BattleScreen(),
      },
    );
  }
}

class PokemonSelectionScreen extends StatefulWidget {
  @override
  _PokemonSelectionScreenState createState() => _PokemonSelectionScreenState();
}

class _PokemonSelectionScreenState extends State<PokemonSelectionScreen> {
  late Future<List<Pokemon>> playerPokemonList;
  late Future<Pokemon> opponentPokemon;

  List<Pokemon> selectedPokemons = [];
  String battleResult = '';

  @override
  void initState() {
    super.initState();
    playerPokemonList = fetchPlayerPokemon(150);
    opponentPokemon = fetchPokemon(Random().nextInt(151) + 1);
  }

  Future<List<Pokemon>> fetchPlayerPokemon(int limit) async {
    final List<int> playerPokemonIds = List.generate(limit, (index) => index + 1);
    final List<Future<Pokemon>> pokemonFutures =
        playerPokemonIds.map((id) => fetchPokemon(id)).toList();
    return await Future.wait(pokemonFutures);
  }

  Future<Pokemon> fetchPokemon(int id) async {
    final response = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/$id/'));
    if (response.statusCode == 200) {
      final pokemonJson = json.decode(response.body);
      final pokemon = Pokemon.fromJson(pokemonJson);
      await pokemon.fetchPokedexInfo();
      await pokemon.fetchDetails();
      return pokemon;
    } else {
      throw Exception('Failed to load Pokemon');
    }
  }

  Future<void> onRefresh() async {
    setState(() {
      selectedPokemons.clear();
      playerPokemonList = fetchPlayerPokemon(150);
      opponentPokemon = fetchPokemon(Random().nextInt(151) + 1);
      battleResult = '';
    });
  }

  void startBattle() {
    if (selectedPokemons.isNotEmpty) {
      final playerAttack = selectedPokemons.fold(0, (sum, pokemon) => sum + pokemon.attack);
      final playerDefense = selectedPokemons.fold(0, (sum, pokemon) => sum + pokemon.defense);
      opponentPokemon.then((opponent) {
        final opponentAttack = opponent.attack;
        final opponentDefense = opponent.defense;

        double playerTotalDamage = playerAttack * selectedPokemons[0].calculateTypeAdvantage(opponent);
        double opponentTotalDamage = opponentAttack * opponent.calculateTypeAdvantage(selectedPokemons[0]);

        String result;
        if (playerTotalDamage > opponentDefense && opponentTotalDamage > playerDefense) {
          result = 'Empate! 🤝';
        } else if (playerTotalDamage > opponentDefense) {
          result = 'Você venceu! 🏆';
        } else if (opponentTotalDamage > playerDefense) {
          result = 'Você perdeu! 💔';
        } else {
          result = 'Empate! 🤝';
        }

        Navigator.pushNamed(context, '/battle', arguments: {
          'playerPokemon': selectedPokemons[0],
          'opponentPokemon': opponent,
          'result': result,
        });
      });
    }
  }

  void regeneratePokemonList() {
    setState(() {
      selectedPokemons.clear();
      playerPokemonList = fetchPlayerPokemon(150);
      battleResult = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Escolha seu Pokémon'),
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: <Widget>[
            FutureBuilder<List<Pokemon>>(
              future: playerPokemonList,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Erro: ${snapshot.error}');
                } else if (snapshot.hasData) {
                  final playerPokemonList = snapshot.data!;
                  return Column(
                    children: [
                      Text('Escolha seus 3 Pokémon:'),
                      for (var i = 0; i < 3; i++)
                        if (i < playerPokemonList.length)
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                selectedPokemons.add(playerPokemonList[i]);
                              });
                            },
                            child: Column(
                              children: [
                                Card(
                                  elevation: 5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        '${playerPokemonList[i].id}. ${playerPokemonList[i].name}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'HP: ${playerPokemonList[i].hp}',
                                        style: TextStyle(
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        'Ataque: ${playerPokemonList[i].attack}',
                                        style: TextStyle(
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        'Defesa: ${playerPokemonList[i].defense}',
                                        style: TextStyle(
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ],
                  );
                } else {
                  return Text('Nenhum Pokémon encontrado.');
                }
              },
            ),
            SizedBox(height: 20),
            if (selectedPokemons.isNotEmpty)
              Column(
                children: [
                  Text(
                    'Seus Pokémon Escolhidos:',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  for (var pokemon in selectedPokemons)
                    Text(
                      '${pokemon.id}. ${pokemon.name}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ElevatedButton(
                    onPressed: () {
                      startBattle();
                    },
                    child: Text(
                      'Iniciar Batalha',
                      style: TextStyle(
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
            SizedBox(height: 20),
            if (battleResult.isNotEmpty)
              Text(
                'Resultado da Batalha: $battleResult',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                regeneratePokemonList();
              },
              child: Text(
                'Regenerar Pokémon',
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BattleScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final Pokemon playerPokemon = args['playerPokemon'];
    final Pokemon opponentPokemon = args['opponentPokemon'];
    final String result = args['result'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Batalha Pokémon'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Batalha Pokémon',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'Seu Pokémon:',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${playerPokemon.id}. ${playerPokemon.name}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'HP: ${playerPokemon.hp}',
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Ataque: ${playerPokemon.attack}',
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Defesa: ${playerPokemon.defense}',
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  'X',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Column(
                  children: [
                    Text(
                      'Oponente:',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${opponentPokemon.id}. ${opponentPokemon.name}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'HP: ${opponentPokemon.hp}',
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Ataque: ${opponentPokemon.attack}',
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Defesa: ${opponentPokemon.defense}',
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Resultado da Batalha:',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              result,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: result.contains('venceu') ? Colors.green : Colors.red,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Voltar para a seleção de Pokémon',
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
