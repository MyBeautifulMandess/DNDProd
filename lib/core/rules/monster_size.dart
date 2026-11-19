/// Размер существа из каталога в клетках игрового поля.
/// dnd.su отдаёт размер свободным текстом с вопросительным знаком и родом
/// («Средняя?», «Большое?») — поэтому сравниваем начало строки.
library;

int monsterCellSize(String rawSize) {
  final size = rawSize.toLowerCase().replaceAll('?', '').trim();
  if (size.startsWith('громадн')) return 4;
  if (size.startsWith('огромн')) return 3;
  if (size.startsWith('больш')) return 2;
  return 1;
}
