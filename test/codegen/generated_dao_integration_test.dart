import '../support/orm_fixture.dart';
import '../support/generated_daos.dart';
import 'sql_generator_contract.dart';

void main() {
  final fixture = OrmFixture()..install();
  test('compiled fixture matches public generator output', () {
    String compact(String value) => value.replaceAll(RegExp(r'\s+'), '');
    final output = const SqlDaoGenerator().generate(input);
    expect(compact(File('test/support/generated_daos.dart').readAsStringSync()),
        compact(output.source));
    expect(ProjectsDao().schema, output.tables.first.schema);
    expect(TasksDao().schema, output.tables.last.schema);
  });
  test(
      'generated multi-table DAOs register, convert, query and enforce foreign keys',
      () async {
    await fixture.open(daos: [ProjectsDao(), TasksDao()], foreignKeys: true);
    final projects = fixture.db.get<ProjectsDao>()!;
    final tasks = fixture.db.get<TasksDao>()!;
    final projectId = await projects.insert({'name': 'Learning'});
    final id =
        await tasks.insert({'project_id': projectId, 'title': 'Read SQL'});
    expect((await tasks.find(id))!['done'], 0);
    expect(
        (await tasks.query().where({'project_id': projectId}).toMap())
            .single['title'],
        'Read SQL');
    await tasks.query().where({'id': id}).updateAll({'done': 1});
    expect((await tasks.find(id))!['done'], 1);
    await expectLater(
        tasks.insert({'project_id': -1, 'title': 'Orphan'}), throwsA(anything));
    await tasks.destroy(id);
    expect(await tasks.count(), 0);
    expect(await projects.count(), 1);
  });
}
