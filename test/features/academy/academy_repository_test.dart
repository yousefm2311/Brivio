import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/academy/domain/models/academy_models.dart';
import 'package:flutter_application_1/features/academy/domain/repositories/academy_repositories.dart';
import 'package:flutter_application_1/features/academy/presentation/viewmodels/academy_viewmodels.dart';

class FakeBranchRepository implements IBranchRepository {
  List<Branch> branches = [
    const Branch(
      id: '20000000-0000-0000-0000-000000000001',
      name: 'Main Campus',
      code: 'CAMPUS-MAIN',
      status: 'active',
    ),
  ];

  @override
  Future<List<Branch>> fetchBranches({
    String? search,
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async => branches;

  @override
  Future<Branch> getBranchById(String id) async =>
      branches.firstWhere((b) => b.id == id);

  @override
  Future<Branch> createBranch(Branch branch) async {
    branches.add(branch);
    return branch;
  }

  @override
  Future<Branch> updateBranch(Branch branch) async {
    final idx = branches.indexWhere((b) => b.id == branch.id);
    if (idx != -1) branches[idx] = branch;
    return branch;
  }

  @override
  Future<void> deleteBranch(String id) async {
    branches.removeWhere((b) => b.id == id);
  }
}

class FakeSubjectRepository implements ISubjectRepository {
  List<SubjectEntity> subjects = [
    const SubjectEntity(
      id: '30000000-0000-0000-0000-000000000001',
      name: 'Computer Science 101',
      code: 'CS-101',
      status: 'active',
    ),
  ];

  @override
  Future<List<SubjectEntity>> fetchSubjects({
    String? search,
    String? status,
  }) async => subjects;

  @override
  Future<SubjectEntity> createSubject(SubjectEntity subject) async {
    subjects.add(subject);
    return subject;
  }

  @override
  Future<SubjectEntity> updateSubject(SubjectEntity subject) async {
    final idx = subjects.indexWhere((s) => s.id == subject.id);
    if (idx != -1) subjects[idx] = subject;
    return subject;
  }

  @override
  Future<void> deleteSubject(String id) async {
    subjects.removeWhere((s) => s.id == id);
  }
}

void main() {
  group('Academy Core Domain Models & ViewModels Unit Tests', () {
    test('Student model parses JSON correctly', () {
      final json = {
        'id': 'e1000000-0000-0000-0000-000000000001',
        'profile_id': 'd0000000-0000-0000-0000-000000000001',
        'student_code': 'STU-001',
        'primary_branch_id': '20000000-0000-0000-0000-000000000001',
        'grade_level': 'Grade 10',
        'school_name': 'Academy High',
        'status': 'active',
        'full_name': 'John Student',
        'email': 'student1@academy.com',
      };

      final student = Student.fromJson(json);
      expect(student.id, 'e1000000-0000-0000-0000-000000000001');
      expect(student.studentCode, 'STU-001');
      expect(student.fullName, 'John Student');
      expect(student.status, 'active');
    });

    test('BranchViewModel fetches branches and manages create state', () async {
      final repo = FakeBranchRepository();
      final vm = BranchViewModel(repo);

      expect(vm.status, AcademyViewState.initial);
      await vm.fetchBranches();
      expect(vm.status, AcademyViewState.loaded);
      expect(vm.branches.length, 1);

      const newBranch = Branch(
        id: '20000000-0000-0000-0000-000000000002',
        name: 'North Branch',
        code: 'CAMPUS-NORTH',
        status: 'active',
      );
      await vm.createBranch(newBranch);
      expect(vm.branches.length, 2);
    });

    test(
      'SubjectViewModel fetches subjects and manages create state',
      () async {
        final repo = FakeSubjectRepository();
        final vm = SubjectViewModel(repo);

        expect(vm.status, AcademyViewState.initial);
        await vm.fetchSubjects();
        expect(vm.status, AcademyViewState.loaded);
        expect(vm.subjects.length, 1);

        const newSubject = SubjectEntity(
          id: '30000000-0000-0000-0000-000000000002',
          name: 'Physics 201',
          code: 'PHYS-201',
          status: 'active',
        );
        await vm.createSubject(newSubject);
        expect(vm.subjects.length, 2);
      },
    );
  });
}
