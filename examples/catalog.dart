// Same market-day program as examples/catalog.quds.

class Product {
  Product({required this.sku, required this.cents, required this.stock});

  final String sku;
  final int cents;
  final int stock;

  int value() => cents * stock;

  bool low() => stock < 5;
}

class CartLine {
  CartLine({required this.units, required this.cents});

  final int units;
  final int cents;

  int total() => units * cents;
}

class Shift {
  Shift({required this.start, required this.end});

  final int start;
  final int end;

  int minutes() {
    if (end >= start) {
      return end - start;
    }
    return end + 1440 - start;
  }
}

int sumList(List<int> values) {
  var total = 0;
  for (final value in values) {
    total += value;
  }
  return total;
}

int minList(List<int> values) {
  var best = values[0];
  for (final value in values) {
    if (value < best) {
      best = value;
    }
  }
  return best;
}

int maxList(List<int> values) {
  var best = values[0];
  for (final value in values) {
    if (value > best) {
      best = value;
    }
  }
  return best;
}

int clampInt(int value, int low, int high) {
  if (value < low) {
    return low;
  }
  if (value > high) {
    return high;
  }
  return value;
}

int factorial(int n) {
  var running = 1;
  var cursor = 2;
  final limit = n > 12 ? 12 : n;
  while (cursor <= limit) {
    running *= cursor;
    cursor += 1;
  }
  return running;
}

int fibonacci(int n) {
  if (n <= 1) {
    return n;
  }
  var previous = 0;
  var current = 1;
  var left = n - 1;
  while (left > 0) {
    final next = previous + current;
    previous = current;
    current = next;
    left -= 1;
  }
  return current;
}

int gcd(int a, int b) {
  var left = a;
  var right = b;
  if (left < 0) {
    left = 0 - left;
  }
  if (right < 0) {
    right = 0 - right;
  }
  while (right != 0) {
    final rest = left % right;
    left = right;
    right = rest;
  }
  return left;
}

int lcm(int a, int b) {
  if (a == 0 || b == 0) {
    return 0;
  }
  return a ~/ gcd(a, b) * b;
}

int collatzSteps(int start) {
  var value = start;
  var steps = 0;
  if (value < 1) {
    return 0;
  }
  while (value != 1 && steps < 40) {
    if (value % 2 == 0) {
      value = value ~/ 2;
    } else {
      value = value * 3 + 1;
    }
    steps += 1;
  }
  return steps;
}

String letterGrade(int score) {
  if (score >= 90) {
    return 'A';
  }
  if (score >= 80) {
    return 'B';
  }
  if (score >= 70) {
    return 'C';
  }
  if (score >= 60) {
    return 'D';
  }
  return 'F';
}

int gpaPoints(int score) {
  if (score >= 90) {
    return 4;
  }
  if (score >= 80) {
    return 3;
  }
  if (score >= 70) {
    return 2;
  }
  if (score >= 60) {
    return 1;
  }
  return 0;
}

int weighted(int a, int b, int c) {
  return (a * 5 + b * 3 + c * 2) ~/ 10;
}

int dayOfYear(int month, int day) {
  final lengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  var cursor = 1;
  var total = day;
  while (cursor < month && cursor <= 12) {
    total += lengths[cursor - 1];
    cursor += 1;
  }
  return total;
}

int daysInMonth(int month) {
  if (month == 2) {
    return 28;
  }
  if (month == 4 || month == 6 || month == 9 || month == 11) {
    return 30;
  }
  return 31;
}

int roundDiv(int cents, int rate) {
  final base = cents * rate;
  final whole = base ~/ 100;
  if (base % 100 >= 50) {
    return whole + 1;
  }
  return whole;
}

int tipOf(int cents, int percent) {
  return roundDiv(cents, percent);
}

int splitBill(int cents, int people) {
  if (people <= 0) {
    return cents;
  }
  final share = cents ~/ people;
  if (cents % people == 0) {
    return share;
  }
  return share + 1;
}

int changeDue(int paid, int owed) {
  if (paid <= owed) {
    return 0;
  }
  return paid - owed;
}

int margin(int price, int cost) {
  if (price <= 0) {
    return 0;
  }
  return (price - cost) * 100 ~/ price;
}

int markup(int cost, int percent) {
  return cost + cost * percent ~/ 100;
}

int reorderQty(int stock, int target) {
  if (stock >= target) {
    return 0;
  }
  return target - stock;
}

int rectangleArea(int width, int height) {
  if (width < 0 || height < 0) {
    return 0;
  }
  return width * height;
}

int rectanglePerimeter(int width, int height) {
  return (width + height) * 2;
}

int overlapLength(int a0, int a1, int b0, int b1) {
  final start = a0 > b0 ? a0 : b0;
  final end = a1 < b1 ? a1 : b1;
  if (end <= start) {
    return 0;
  }
  return end - start;
}

int distanceSquared(int x0, int y0, int x1, int y1) {
  final dx = x1 - x0;
  final dy = y1 - y0;
  return dx * dx + dy * dy;
}

int simpleInterest(int principal, int rate, int years) {
  if (years < 0) {
    return principal;
  }
  return principal + principal * rate * years ~/ 100;
}

int compoundSteps(int principal, int rate, int years) {
  var balance = principal;
  var left = years;
  if (left < 0) {
    left = 0;
  }
  while (left > 0) {
    balance += balance * rate ~/ 100;
    left -= 1;
  }
  return balance;
}

int payroll(int hours, int rate) {
  if (hours <= 40) {
    return hours * rate;
  }
  final extra = hours - 40;
  return 40 * rate + extra * rate * 3 ~/ 2;
}

int netPay(int gross, int taxRate) {
  final tax = gross * taxRate ~/ 100;
  if (tax >= gross) {
    return 0;
  }
  return gross - tax;
}

int countChar(String text, String mark) {
  if (mark.length == 0) {
    return 0;
  }
  final parts = text.split(mark);
  return parts.length - 1;
}

String shout(String text) {
  return text.trim().toUpperCase();
}

int wordScore(String text) {
  if (text.isEmpty) {
    return 0;
  }
  return text.trim().length + text.indexOf("a");
}

int boolBit(bool value) {
  if (value) {
    return 1;
  }
  return 0;
}

bool opensWith(String text, String prefix) {
  return text.startsWith(prefix);
}

int appleTier(int units, int cents) {
  if (units >= 24) {
    return cents * units * 80 ~/ 100;
  }
  if (units >= 12) {
    return cents * units * 90 ~/ 100;
  }
  return cents * units;
}

int breadTier(int units, int cents) {
  if (units >= 20) {
    return cents * units * 85 ~/ 100;
  }
  if (units >= 10) {
    return cents * units * 95 ~/ 100;
  }
  return cents * units;
}

int milkTier(int units, int cents) {
  if (units >= 18) {
    return cents * units * 88 ~/ 100;
  }
  if (units >= 6) {
    return cents * units * 94 ~/ 100;
  }
  return cents * units;
}

int riceTier(int units, int cents) {
  if (units >= 30) {
    return cents * units * 75 ~/ 100;
  }
  if (units >= 10) {
    return cents * units * 90 ~/ 100;
  }
  return cents * units;
}

int oilTier(int units, int cents) {
  if (units >= 12) {
    return cents * units * 82 ~/ 100;
  }
  if (units >= 4) {
    return cents * units * 92 ~/ 100;
  }
  return cents * units;
}

int soapTier(int units, int cents) {
  if (units >= 16) {
    return cents * units * 84 ~/ 100;
  }
  if (units >= 8) {
    return cents * units * 93 ~/ 100;
  }
  return cents * units;
}

int saltTier(int units, int cents) {
  if (units >= 40) {
    return cents * units * 70 ~/ 100;
  }
  if (units >= 20) {
    return cents * units * 85 ~/ 100;
  }
  return cents * units;
}

int honeyTier(int units, int cents) {
  if (units >= 8) {
    return cents * units * 90 ~/ 100;
  }
  if (units >= 4) {
    return cents * units * 96 ~/ 100;
  }
  return cents * units;
}

int teaTier(int units, int cents) {
  if (units >= 15) {
    return cents * units * 86 ~/ 100;
  }
  if (units >= 5) {
    return cents * units * 94 ~/ 100;
  }
  return cents * units;
}

int coffeeTier(int units, int cents) {
  if (units >= 10) {
    return cents * units * 83 ~/ 100;
  }
  if (units >= 4) {
    return cents * units * 91 ~/ 100;
  }
  return cents * units;
}

int flourTier(int units, int cents) {
  if (units >= 25) {
    return cents * units * 78 ~/ 100;
  }
  if (units >= 10) {
    return cents * units * 90 ~/ 100;
  }
  return cents * units;
}

int sugarTier(int units, int cents) {
  if (units >= 22) {
    return cents * units * 80 ~/ 100;
  }
  if (units >= 8) {
    return cents * units * 92 ~/ 100;
  }
  return cents * units;
}

int northShip(int grams, int zone) {
  var fee = 25;
  if (grams >= 2000) {
    fee = 90;
  } else if (grams >= 800) {
    fee = 55;
  }
  if (zone > 1) {
    fee += zone * 15;
  }
  return fee;
}

int southShip(int grams, int zone) {
  var fee = 20;
  if (grams >= 1800) {
    fee = 80;
  } else if (grams >= 700) {
    fee = 50;
  }
  if (zone > 1) {
    fee += zone * 15;
  }
  return fee;
}

int eastShip(int grams, int zone) {
  var fee = 30;
  if (grams >= 2500) {
    fee = 110;
  } else if (grams >= 1000) {
    fee = 60;
  }
  if (zone > 1) {
    fee += zone * 15;
  }
  return fee;
}

int westShip(int grams, int zone) {
  var fee = 18;
  if (grams >= 1500) {
    fee = 70;
  } else if (grams >= 600) {
    fee = 45;
  }
  if (zone > 1) {
    fee += zone * 15;
  }
  return fee;
}

int portShip(int grams, int zone) {
  var fee = 35;
  if (grams >= 3000) {
    fee = 140;
  } else if (grams >= 1200) {
    fee = 75;
  }
  if (zone > 1) {
    fee += zone * 15;
  }
  return fee;
}

int hillShip(int grams, int zone) {
  var fee = 15;
  if (grams >= 1200) {
    fee = 65;
  } else if (grams >= 500) {
    fee = 40;
  }
  if (zone > 1) {
    fee += zone * 15;
  }
  return fee;
}

int rentLate(int days, int due) {
  if (days <= 3) {
    return 0;
  }
  final extra = (days - 3) * 15;
  if (extra > due * 20 ~/ 100) {
    return due * 20 ~/ 100;
  }
  return extra;
}

int stallLate(int days, int due) {
  if (days <= 2) {
    return 0;
  }
  final extra = (days - 2) * 10;
  if (extra > due * 25 ~/ 100) {
    return due * 25 ~/ 100;
  }
  return extra;
}

int crateLate(int days, int due) {
  if (days <= 5) {
    return 0;
  }
  final extra = (days - 5) * 8;
  if (extra > due * 15 ~/ 100) {
    return due * 15 ~/ 100;
  }
  return extra;
}

int coolerLate(int days, int due) {
  if (days <= 1) {
    return 0;
  }
  final extra = (days - 1) * 20;
  if (extra > due * 30 ~/ 100) {
    return due * 30 ~/ 100;
  }
  return extra;
}

int licenseLate(int days, int due) {
  if (days <= 7) {
    return 0;
  }
  final extra = (days - 7) * 12;
  if (extra > due * 10 ~/ 100) {
    return due * 10 ~/ 100;
  }
  return extra;
}

int clerkBonus(int score, int base) {
  if (score >= 95) {
    return base * 20 ~/ 100;
  }
  if (score >= 80) {
    return base * 10 ~/ 100;
  }
  return 0;
}

int bakerBonus(int score, int base) {
  if (score >= 90) {
    return base * 15 ~/ 100;
  }
  if (score >= 75) {
    return base * 8 ~/ 100;
  }
  return 0;
}

int driverBonus(int score, int base) {
  if (score >= 98) {
    return base * 25 ~/ 100;
  }
  if (score >= 85) {
    return base * 12 ~/ 100;
  }
  return 0;
}

int buyerBonus(int score, int base) {
  if (score >= 88) {
    return base * 18 ~/ 100;
  }
  if (score >= 70) {
    return base * 9 ~/ 100;
  }
  return 0;
}

int ripeSum(List<int> values) {
  var total = 0;
  for (final value in values) {
    if (value > 5) {
      total += value;
    }
  }
  return total;
}

int heavySum(List<int> values) {
  var total = 0;
  for (final value in values) {
    if (value > 20) {
      total += value;
    }
  }
  return total;
}

int warmSum(List<int> values) {
  var total = 0;
  for (final value in values) {
    if (value > 30) {
      total += value;
    }
  }
  return total;
}

int loudSum(List<int> values) {
  var total = 0;
  for (final value in values) {
    if (value > 2) {
      total += value;
    }
  }
  return total;
}

int tallSum(List<int> values) {
  var total = 0;
  for (final value in values) {
    if (value > 100) {
      total += value;
    }
  }
  return total;
}

int plainDigits(int number) {
  var rest = number;
  if (rest < 0) {
    rest = 0 - rest;
  }
  var total = 0;
  while (rest > 0) {
    total += (rest % 10) * 1;
    rest = rest ~/ 10;
  }
  return total;
}

int doubleDigits(int number) {
  var rest = number;
  if (rest < 0) {
    rest = 0 - rest;
  }
  var total = 0;
  while (rest > 0) {
    total += (rest % 10) * 2;
    rest = rest ~/ 10;
  }
  return total;
}

int tripleDigits(int number) {
  var rest = number;
  if (rest < 0) {
    rest = 0 - rest;
  }
  var total = 0;
  while (rest > 0) {
    total += (rest % 10) * 3;
    rest = rest ~/ 10;
  }
  return total;
}

int rateAppleCrate(int units) => units * 100 + 0;
int rateBreadCrate(int units) => units * 101 + 1;
int rateMilkCrate(int units) => units * 102 + 2;
int rateRiceCrate(int units) => units * 103 + 3;
int rateOilCrate(int units) => units * 104 + 4;
int rateSoapCrate(int units) => units * 105 + 5;
int rateSaltCrate(int units) => units * 106 + 6;
int rateHoneyCrate(int units) => units * 107 + 7;
int rateTeaCrate(int units) => units * 108 + 8;
int rateCoffeeCrate(int units) => units * 109 + 9;
int rateFlourCrate(int units) => units * 110 + 10;
int rateSugarCrate(int units) => units * 111 + 11;
int rateEggCrate(int units) => units * 112 + 12;
int rateCheeseCrate(int units) => units * 113 + 13;
int rateOatCrate(int units) => units * 114 + 14;
int rateSpiceCrate(int units) => units * 115 + 15;
int rateDateCrate(int units) => units * 116 + 16;
int rateFigCrate(int units) => units * 117 + 17;
int rateGrapeCrate(int units) => units * 118 + 18;
int rateOliveCrate(int units) => units * 119 + 0;
int ratePepperCrate(int units) => units * 120 + 1;
int rateOnionCrate(int units) => units * 121 + 2;
int rateGarlicCrate(int units) => units * 122 + 3;
int rateTomatoCrate(int units) => units * 123 + 4;
int ratePotatoCrate(int units) => units * 124 + 5;
int rateCarrotCrate(int units) => units * 125 + 6;
int rateLemonCrate(int units) => units * 126 + 7;
int rateMintCrate(int units) => units * 127 + 8;
int rateBasilCrate(int units) => units * 128 + 9;
int rateCuminCrate(int units) => units * 129 + 10;
int rateYeastCrate(int units) => units * 130 + 11;
int rateButterCrate(int units) => units * 131 + 12;
int rateCreamCrate(int units) => units * 132 + 13;
int rateLentilCrate(int units) => units * 133 + 14;
int rateBeanCrate(int units) => units * 134 + 15;
int rateNutCrate(int units) => units * 135 + 16;
int rateBarleyCrate(int units) => units * 136 + 17;
int rateMilletCrate(int units) => units * 100 + 18;
int rateSesameCrate(int units) => units * 101 + 0;
int rateThymeCrate(int units) => units * 102 + 1;
int rateGingerCrate(int units) => units * 103 + 2;
int rateCocoaCrate(int units) => units * 104 + 3;
int rateVanillaCrate(int units) => units * 105 + 4;
int rateWalnutCrate(int units) => units * 106 + 5;
int rateAlmondCrate(int units) => units * 107 + 6;
int ratePistachioCrate(int units) => units * 108 + 7;
int rateChickpeaCrate(int units) => units * 109 + 8;
int rateSpinachCrate(int units) => units * 110 + 9;
int rateCabbageCrate(int units) => units * 111 + 10;
int rateCucumberCrate(int units) => units * 112 + 11;
int rateOrangeCrate(int units) => units * 113 + 12;
int rateMelonCrate(int units) => units * 114 + 13;
int ratePeachCrate(int units) => units * 115 + 14;
int ratePlumCrate(int units) => units * 116 + 15;
int rateCherryCrate(int units) => units * 117 + 16;
int rateMangoCrate(int units) => units * 118 + 17;
int rateBananaCrate(int units) => units * 119 + 18;
int rateYogurtCrate(int units) => units * 120 + 0;
int rateLabnehCrate(int units) => units * 121 + 1;
int rateHalvaCrate(int units) => units * 122 + 2;
int rateTahiniCrate(int units) => units * 123 + 3;
int rateAppleSack(int units) => units * 124 + 4;
int rateBreadSack(int units) => units * 125 + 5;
int rateMilkSack(int units) => units * 126 + 6;
int rateRiceSack(int units) => units * 127 + 7;
int rateOilSack(int units) => units * 128 + 8;
int rateSoapSack(int units) => units * 129 + 9;
int rateSaltSack(int units) => units * 130 + 10;
int rateHoneySack(int units) => units * 131 + 11;
int rateTeaSack(int units) => units * 132 + 12;
int rateCoffeeSack(int units) => units * 133 + 13;
int rateFlourSack(int units) => units * 134 + 14;
int rateSugarSack(int units) => units * 135 + 15;
int rateEggSack(int units) => units * 136 + 16;
int rateCheeseSack(int units) => units * 100 + 17;
int rateOatSack(int units) => units * 101 + 18;
int rateSpiceSack(int units) => units * 102 + 0;
int rateDateSack(int units) => units * 103 + 1;
int rateFigSack(int units) => units * 104 + 2;
int rateGrapeSack(int units) => units * 105 + 3;
int rateOliveSack(int units) => units * 106 + 4;
int ratePepperSack(int units) => units * 107 + 5;
int rateOnionSack(int units) => units * 108 + 6;
int rateGarlicSack(int units) => units * 109 + 7;
int rateTomatoSack(int units) => units * 110 + 8;
int ratePotatoSack(int units) => units * 111 + 9;
int rateCarrotSack(int units) => units * 112 + 10;
int rateLemonSack(int units) => units * 113 + 11;
int rateMintSack(int units) => units * 114 + 12;
int rateBasilSack(int units) => units * 115 + 13;
int rateCuminSack(int units) => units * 116 + 14;

int digest() {
  var total = 0;
  total += sumList([4, 5, 6]);
  total += minList([4, 1, 7]);
  total += maxList([4, 1, 7]);
  total += clampInt(12, 0, 9);
  total += factorial(6);
  total += fibonacci(10);
  total += gcd(48, 18);
  total += lcm(12, 18);
  total += collatzSteps(12);
  total += letterGrade(92).length;
  total += gpaPoints(75);
  total += weighted(80, 90, 70);
  total += dayOfYear(3, 1);
  total += daysInMonth(2);
  total += roundDiv(199, 15);
  total += tipOf(2000, 10);
  total += splitBill(1000, 3);
  total += changeDue(500, 320);
  total += margin(250, 180);
  total += markup(180, 25);
  total += reorderQty(4, 12);
  total += rectangleArea(6, 4);
  total += rectanglePerimeter(6, 4);
  total += overlapLength(1, 5, 3, 8);
  total += distanceSquared(1, 2, 4, 6);
  total += simpleInterest(1000, 5, 2);
  total += compoundSteps(1000, 10, 2);
  total += payroll(42, 20);
  total += netPay(800, 10);
  total += countChar("a-b-c", "-");
  total += shout("  ada ").length;
  total += wordScore("ada");
  total += boolBit(true);
  total += boolBit(opensWith("market", "mar"));
  total += appleTier(10, 40);
  total += breadTier(10, 40);
  total += milkTier(10, 40);
  total += riceTier(10, 40);
  total += oilTier(10, 40);
  total += soapTier(10, 40);
  total += saltTier(10, 40);
  total += honeyTier(10, 40);
  total += teaTier(10, 40);
  total += coffeeTier(10, 40);
  total += flourTier(10, 40);
  total += sugarTier(10, 40);
  total += northShip(900, 2);
  total += southShip(900, 2);
  total += eastShip(900, 2);
  total += westShip(900, 2);
  total += portShip(900, 2);
  total += hillShip(900, 2);
  total += rentLate(12, 500);
  total += stallLate(12, 500);
  total += crateLate(12, 500);
  total += coolerLate(12, 500);
  total += licenseLate(12, 500);
  total += clerkBonus(88, 200);
  total += bakerBonus(88, 200);
  total += driverBonus(88, 200);
  total += buyerBonus(88, 200);
  total += ripeSum([3, 8, 1, 9]);
  total += heavySum([3, 8, 1, 9]);
  total += warmSum([3, 8, 1, 9]);
  total += loudSum([3, 8, 1, 9]);
  total += tallSum([3, 8, 1, 9]);
  total += plainDigits(2468);
  total += doubleDigits(2468);
  total += tripleDigits(2468);
  total += rateAppleCrate(3);
  total += rateBreadCrate(3);
  total += rateMilkCrate(3);
  total += rateRiceCrate(3);
  total += rateOilCrate(3);
  total += rateSoapCrate(3);
  total += rateSaltCrate(3);
  total += rateHoneyCrate(3);
  total += rateTeaCrate(3);
  total += rateCoffeeCrate(3);
  total += rateFlourCrate(3);
  total += rateSugarCrate(3);
  total += rateEggCrate(3);
  total += rateCheeseCrate(3);
  total += rateOatCrate(3);
  total += rateSpiceCrate(3);
  total += rateDateCrate(3);
  total += rateFigCrate(3);
  total += rateGrapeCrate(3);
  total += rateOliveCrate(3);
  total += ratePepperCrate(3);
  total += rateOnionCrate(3);
  total += rateGarlicCrate(3);
  total += rateTomatoCrate(3);
  total += ratePotatoCrate(3);
  total += rateCarrotCrate(3);
  total += rateLemonCrate(3);
  total += rateMintCrate(3);
  total += rateBasilCrate(3);
  total += rateCuminCrate(3);
  total += rateYeastCrate(3);
  total += rateButterCrate(3);
  total += rateCreamCrate(3);
  total += rateLentilCrate(3);
  total += rateBeanCrate(3);
  total += rateNutCrate(3);
  total += rateBarleyCrate(3);
  total += rateMilletCrate(3);
  total += rateSesameCrate(3);
  total += rateThymeCrate(3);
  total += rateGingerCrate(3);
  total += rateCocoaCrate(3);
  total += rateVanillaCrate(3);
  total += rateWalnutCrate(3);
  total += rateAlmondCrate(3);
  total += ratePistachioCrate(3);
  total += rateChickpeaCrate(3);
  total += rateSpinachCrate(3);
  total += rateCabbageCrate(3);
  total += rateCucumberCrate(3);
  total += rateOrangeCrate(3);
  total += rateMelonCrate(3);
  total += ratePeachCrate(3);
  total += ratePlumCrate(3);
  total += rateCherryCrate(3);
  total += rateMangoCrate(3);
  total += rateBananaCrate(3);
  total += rateYogurtCrate(3);
  total += rateLabnehCrate(3);
  total += rateHalvaCrate(3);
  total += rateTahiniCrate(3);
  total += rateAppleSack(3);
  total += rateBreadSack(3);
  total += rateMilkSack(3);
  total += rateRiceSack(3);
  total += rateOilSack(3);
  total += rateSoapSack(3);
  total += rateSaltSack(3);
  total += rateHoneySack(3);
  total += rateTeaSack(3);
  total += rateCoffeeSack(3);
  total += rateFlourSack(3);
  total += rateSugarSack(3);
  total += rateEggSack(3);
  total += rateCheeseSack(3);
  total += rateOatSack(3);
  total += rateSpiceSack(3);
  total += rateDateSack(3);
  total += rateFigSack(3);
  total += rateGrapeSack(3);
  total += rateOliveSack(3);
  total += ratePepperSack(3);
  total += rateOnionSack(3);
  total += rateGarlicSack(3);
  total += rateTomatoSack(3);
  total += ratePotatoSack(3);
  total += rateCarrotSack(3);
  total += rateLemonSack(3);
  total += rateMintSack(3);
  total += rateBasilSack(3);
  total += rateCuminSack(3);
  final product = Product(sku: 'A1', cents: 250, stock: 4);
  total += product.value();
  if (product.low()) {
    total += 1;
  }
  final line = CartLine(units: 3, cents: 40);
  total += line.total();
  final shift = Shift(start: 22 * 60, end: 6 * 60);
  total += shift.minutes();
  return total;
}

void main() {
  final product = Product(sku: 'A1', cents: 250, stock: 4);
  final shift = Shift(start: 22 * 60, end: 6 * 60);
  print('day');
  print(digest());
  print(product.value());
  print(product.low());
  print(shift.minutes());
  print(letterGrade(92));
  print(sumList([4, 5, 6]));
}
