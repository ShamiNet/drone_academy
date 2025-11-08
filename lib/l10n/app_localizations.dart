import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get noResultsFound;

  /// No description provided for @trainees.
  ///
  /// In en, this message translates to:
  /// **'Trainees'**
  String get trainees;

  /// No description provided for @activeCompetition.
  ///
  /// In en, this message translates to:
  /// **'Active Competition'**
  String get activeCompetition;

  /// No description provided for @activeCompetitionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allow trainees to participate in this competition.'**
  String get activeCompetitionSubtitle;

  /// No description provided for @addCompetition.
  ///
  /// In en, this message translates to:
  /// **'Add Competition'**
  String get addCompetition;

  /// No description provided for @addDailyNote.
  ///
  /// In en, this message translates to:
  /// **'Add Daily Note'**
  String get addDailyNote;

  /// No description provided for @addNewCompetition.
  ///
  /// In en, this message translates to:
  /// **'Add New Competition'**
  String get addNewCompetition;

  /// No description provided for @addNewNode.
  ///
  /// In en, this message translates to:
  /// **'Add New Node'**
  String get addNewNode;

  /// No description provided for @addSession.
  ///
  /// In en, this message translates to:
  /// **'Add Session'**
  String get addSession;

  /// No description provided for @addNewTraining.
  ///
  /// In en, this message translates to:
  /// **'Add New Training'**
  String get addNewTraining;

  /// No description provided for @addNodeBelow.
  ///
  /// In en, this message translates to:
  /// **'Add Node Below'**
  String get addNodeBelow;

  /// No description provided for @addRootNode.
  ///
  /// In en, this message translates to:
  /// **'Add Root Node'**
  String get addRootNode;

  /// No description provided for @addTraining.
  ///
  /// In en, this message translates to:
  /// **'Add Training'**
  String get addTraining;

  /// No description provided for @addTrainingResult.
  ///
  /// In en, this message translates to:
  /// **'Add Training Result'**
  String get addTrainingResult;

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboard;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Drone Academy'**
  String get appTitle;

  /// No description provided for @areYouSureDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this?'**
  String get areYouSureDelete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @checkBackLater.
  ///
  /// In en, this message translates to:
  /// **'Check back later!'**
  String get checkBackLater;

  /// No description provided for @competitions.
  ///
  /// In en, this message translates to:
  /// **'Competitions'**
  String get competitions;

  /// No description provided for @confirmDeletion.
  ///
  /// In en, this message translates to:
  /// **'Confirm Deletion'**
  String get confirmDeletion;

  /// No description provided for @createNewAccount.
  ///
  /// In en, this message translates to:
  /// **'Create New Account'**
  String get createNewAccount;

  /// No description provided for @dailyNotes.
  ///
  /// In en, this message translates to:
  /// **'Daily Notes'**
  String get dailyNotes;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteNode.
  ///
  /// In en, this message translates to:
  /// **'Delete Node'**
  String get deleteNode;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign Up'**
  String get dontHaveAccount;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editCompetition.
  ///
  /// In en, this message translates to:
  /// **'Edit Competition'**
  String get editCompetition;

  /// No description provided for @editNode.
  ///
  /// In en, this message translates to:
  /// **'Edit Node'**
  String get editNode;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @editRoleFor.
  ///
  /// In en, this message translates to:
  /// **'Edit Role for'**
  String get editRoleFor;

  /// No description provided for @editTraining.
  ///
  /// In en, this message translates to:
  /// **'Edit Training'**
  String get editTraining;

  /// No description provided for @editStep.
  ///
  /// In en, this message translates to:
  /// **'Edit Step'**
  String get editStep;

  /// No description provided for @saveAsImage.
  ///
  /// In en, this message translates to:
  /// **'Save as Image'**
  String get saveAsImage;

  /// No description provided for @viewManual.
  ///
  /// In en, this message translates to:
  /// **'View Manual'**
  String get viewManual;

  /// No description provided for @recenterView.
  ///
  /// In en, this message translates to:
  /// **'Recenter View'**
  String get recenterView;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @enterDescription.
  ///
  /// In en, this message translates to:
  /// **'Please enter a description'**
  String get enterDescription;

  /// No description provided for @enterLevel.
  ///
  /// In en, this message translates to:
  /// **'Please enter a level'**
  String get enterLevel;

  /// No description provided for @enterNoteHere.
  ///
  /// In en, this message translates to:
  /// **'Enter note here...'**
  String get enterNoteHere;

  /// No description provided for @enterTitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get enterTitle;

  /// No description provided for @enterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get enterValidNumber;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @iAmATrainee.
  ///
  /// In en, this message translates to:
  /// **'I am a Trainee'**
  String get iAmATrainee;

  /// No description provided for @iAmATrainer.
  ///
  /// In en, this message translates to:
  /// **'I am a Trainer'**
  String get iAmATrainer;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @mastery.
  ///
  /// In en, this message translates to:
  /// **'Mastery'**
  String get mastery;

  /// No description provided for @myProgress.
  ///
  /// In en, this message translates to:
  /// **'My Progress'**
  String get myProgress;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @masteryPercentage.
  ///
  /// In en, this message translates to:
  /// **'Mastery Percentage'**
  String get masteryPercentage;

  /// No description provided for @noActiveCompetitions.
  ///
  /// In en, this message translates to:
  /// **'No active competitions right now.'**
  String get noActiveCompetitions;

  /// No description provided for @noDataToBuildChart.
  ///
  /// In en, this message translates to:
  /// **'No data found to build the chart.'**
  String get noDataToBuildChart;

  /// No description provided for @noNotesRecorded.
  ///
  /// In en, this message translates to:
  /// **'No notes recorded yet.'**
  String get noNotesRecorded;

  /// No description provided for @noResultsRecorded.
  ///
  /// In en, this message translates to:
  /// **'No results recorded yet.'**
  String get noResultsRecorded;

  /// No description provided for @notYetTrained.
  ///
  /// In en, this message translates to:
  /// **'Not yet trained'**
  String get notYetTrained;

  /// No description provided for @noResultsRecordedYetCheckBackLater.
  ///
  /// In en, this message translates to:
  /// **'No results recorded yet. Check back later!'**
  String get noResultsRecordedYetCheckBackLater;

  /// No description provided for @noTrainees.
  ///
  /// In en, this message translates to:
  /// **'No trainees found'**
  String get noTrainees;

  /// No description provided for @noTraineesFound.
  ///
  /// In en, this message translates to:
  /// **'No trainees found.'**
  String get noTraineesFound;

  /// No description provided for @noTrainingsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No trainings available yet.'**
  String get noTrainingsAvailable;

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found.'**
  String get noUsersFound;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @organizationalStructure.
  ///
  /// In en, this message translates to:
  /// **'Organizational Structure'**
  String get organizationalStructure;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @profilePictureUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated!'**
  String get profilePictureUpdated;

  /// No description provided for @results.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get results;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @searchCompetition.
  ///
  /// In en, this message translates to:
  /// **'Search for a competition...'**
  String get searchCompetition;

  /// No description provided for @searchTrainee.
  ///
  /// In en, this message translates to:
  /// **'Search for a trainee...'**
  String get searchTrainee;

  /// No description provided for @searchTraining.
  ///
  /// In en, this message translates to:
  /// **'Search for a training...'**
  String get searchTraining;

  /// No description provided for @selectCompetitionToStart.
  ///
  /// In en, this message translates to:
  /// **'Select Competition to Start'**
  String get selectCompetitionToStart;

  /// No description provided for @selectTraining.
  ///
  /// In en, this message translates to:
  /// **'Select Training'**
  String get selectTraining;

  /// No description provided for @selectYourRole.
  ///
  /// In en, this message translates to:
  /// **'Select your role:'**
  String get selectYourRole;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @startCompetitionTest.
  ///
  /// In en, this message translates to:
  /// **'Start Competition Test'**
  String get startCompetitionTest;

  /// No description provided for @training.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get training;

  /// No description provided for @trainers.
  ///
  /// In en, this message translates to:
  /// **'Trainers'**
  String get trainers;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'التاريخ'**
  String get date;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'وقت الانتهاء'**
  String get endTime;

  /// No description provided for @sessionTitle.
  ///
  /// In en, this message translates to:
  /// **'عنوان الحصة'**
  String get sessionTitle;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'وقت البدء'**
  String get startTime;

  /// No description provided for @trainer.
  ///
  /// In en, this message translates to:
  /// **'المدرب'**
  String get trainer;

  /// No description provided for @trainings.
  ///
  /// In en, this message translates to:
  /// **'Trainings'**
  String get trainings;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get welcome;

  /// No description provided for @moveNode.
  ///
  /// In en, this message translates to:
  /// **'Move Node'**
  String get moveNode;

  /// No description provided for @selectNewParent.
  ///
  /// In en, this message translates to:
  /// **'Select New Parent'**
  String get selectNewParent;

  /// No description provided for @noOtherNodesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No other nodes available to move to.'**
  String get noOtherNodesAvailable;

  /// No description provided for @cannotMoveNodeToItself.
  ///
  /// In en, this message translates to:
  /// **'Cannot move a node to be under itself.'**
  String get cannotMoveNodeToItself;

  /// No description provided for @usersOrgChart.
  ///
  /// In en, this message translates to:
  /// **'Users Org Chart'**
  String get usersOrgChart;

  /// No description provided for @competitionsOrgChart.
  ///
  /// In en, this message translates to:
  /// **'Competitions Org Chart'**
  String get competitionsOrgChart;

  /// No description provided for @trainingsOrgChart.
  ///
  /// In en, this message translates to:
  /// **'Trainings Org Chart'**
  String get trainingsOrgChart;

  /// No description provided for @exportAsPdf.
  ///
  /// In en, this message translates to:
  /// **'Export as PDF'**
  String get exportAsPdf;

  /// No description provided for @addUser.
  ///
  /// In en, this message translates to:
  /// **'Add User'**
  String get addUser;

  /// No description provided for @createUser.
  ///
  /// In en, this message translates to:
  /// **'Create User'**
  String get createUser;

  /// No description provided for @noStepsAdded.
  ///
  /// In en, this message translates to:
  /// **'No steps added for this training yet.'**
  String get noStepsAdded;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @trainingSteps.
  ///
  /// In en, this message translates to:
  /// **'Training Steps'**
  String get trainingSteps;

  /// No description provided for @noStepsYet.
  ///
  /// In en, this message translates to:
  /// **'No steps yet. Start by adding some steps!'**
  String get noStepsYet;

  /// No description provided for @selectCompetitionToViewLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Select Competition to View Leaderboard'**
  String get selectCompetitionToViewLeaderboard;

  /// No description provided for @leaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboard;

  /// No description provided for @trainingsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Trainings Completed'**
  String get trainingsCompleted;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @scoreEvolution.
  ///
  /// In en, this message translates to:
  /// **'Score Evolution'**
  String get scoreEvolution;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @noScheduleAvailable.
  ///
  /// In en, this message translates to:
  /// **'No schedule available.'**
  String get noScheduleAvailable;

  /// No description provided for @noResultsYet.
  ///
  /// In en, this message translates to:
  /// **'No results yet.'**
  String get noResultsYet;

  /// No description provided for @passwordMinChars.
  ///
  /// In en, this message translates to:
  /// **'Password (at least 6 characters)'**
  String get passwordMinChars;

  /// No description provided for @selectTrainingToSeeProgress.
  ///
  /// In en, this message translates to:
  /// **'Select Training to See Progress'**
  String get selectTrainingToSeeProgress;

  /// No description provided for @latestScore.
  ///
  /// In en, this message translates to:
  /// **'Latest Score:'**
  String get latestScore;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @manageSteps.
  ///
  /// In en, this message translates to:
  /// **'Manage Training Steps'**
  String get manageSteps;

  /// No description provided for @addStep.
  ///
  /// In en, this message translates to:
  /// **'Add Step'**
  String get addStep;

  /// No description provided for @stepTitle.
  ///
  /// In en, this message translates to:
  /// **'Step Title'**
  String get stepTitle;

  /// No description provided for @stepType.
  ///
  /// In en, this message translates to:
  /// **'Step Type'**
  String get stepType;

  /// No description provided for @checklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist (text)'**
  String get checklist;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @videoThumbnail.
  ///
  /// In en, this message translates to:
  /// **'Video Thumbnail'**
  String get videoThumbnail;

  /// No description provided for @analyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing...'**
  String get analyzing;

  /// No description provided for @getRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Get Recommendation'**
  String get getRecommendation;

  /// No description provided for @noResultsToAnalyze.
  ///
  /// In en, this message translates to:
  /// **'No results to analyze.'**
  String get noResultsToAnalyze;

  /// No description provided for @allTrainingsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! You have mastered all available trainings.'**
  String get allTrainingsCompleted;

  /// No description provided for @videoUrl.
  ///
  /// In en, this message translates to:
  /// **'Video URL (YouTube example)'**
  String get videoUrl;

  /// No description provided for @noNotesRecordedYetCheckBackLater.
  ///
  /// In en, this message translates to:
  /// **'No notes recorded yet. Check back later!'**
  String get noNotesRecordedYetCheckBackLater;

  /// No description provided for @moveToTop.
  ///
  /// In en, this message translates to:
  /// **'Move to Top'**
  String get moveToTop;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move Up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move Down'**
  String get moveDown;

  /// No description provided for @cropImage.
  ///
  /// In en, this message translates to:
  /// **'Crop Image'**
  String get cropImage;

  /// No description provided for @equipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get equipment;

  /// No description provided for @manageEquipment.
  ///
  /// In en, this message translates to:
  /// **'Manage Equipment'**
  String get manageEquipment;

  /// No description provided for @addEquipment.
  ///
  /// In en, this message translates to:
  /// **'Add Equipment'**
  String get addEquipment;

  /// No description provided for @editEquipment.
  ///
  /// In en, this message translates to:
  /// **'Edit Equipment'**
  String get editEquipment;

  /// No description provided for @equipmentName.
  ///
  /// In en, this message translates to:
  /// **'Equipment Name (or Serial Number)'**
  String get equipmentName;

  /// No description provided for @equipmentType.
  ///
  /// In en, this message translates to:
  /// **'Equipment Type'**
  String get equipmentType;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @drone.
  ///
  /// In en, this message translates to:
  /// **'Drone'**
  String get drone;

  /// No description provided for @battery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get battery;

  /// No description provided for @controller.
  ///
  /// In en, this message translates to:
  /// **'Controller'**
  String get controller;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @inUse.
  ///
  /// In en, this message translates to:
  /// **'In Use'**
  String get inUse;

  /// No description provided for @inMaintenance.
  ///
  /// In en, this message translates to:
  /// **'In Maintenance'**
  String get inMaintenance;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notes;

  /// No description provided for @totalFlightHours.
  ///
  /// In en, this message translates to:
  /// **'Total Flight Hours (optional)'**
  String get totalFlightHours;

  /// No description provided for @totalChargeCycles.
  ///
  /// In en, this message translates to:
  /// **'Total Charge Cycles (for Batteries)'**
  String get totalChargeCycles;

  /// No description provided for @lastMaintenanceDate.
  ///
  /// In en, this message translates to:
  /// **'Last Maintenance Date (optional)'**
  String get lastMaintenanceDate;

  /// No description provided for @noEquipmentAddedYet.
  ///
  /// In en, this message translates to:
  /// **'No equipment added yet.'**
  String get noEquipmentAddedYet;

  /// No description provided for @lookup.
  ///
  /// In en, this message translates to:
  /// **'Lookup'**
  String get lookup;

  /// No description provided for @checkOut.
  ///
  /// In en, this message translates to:
  /// **'Check Out'**
  String get checkOut;

  /// No description provided for @checkIn.
  ///
  /// In en, this message translates to:
  /// **'Check In'**
  String get checkIn;

  /// No description provided for @checkedOutBy.
  ///
  /// In en, this message translates to:
  /// **'Checked Out By'**
  String get checkedOutBy;

  /// No description provided for @equipmentLog.
  ///
  /// In en, this message translates to:
  /// **'Equipment Log'**
  String get equipmentLog;

  /// No description provided for @checkInItem.
  ///
  /// In en, this message translates to:
  /// **'Check In Item'**
  String get checkInItem;

  /// No description provided for @notesOnReturn.
  ///
  /// In en, this message translates to:
  /// **'Notes on Return (e.g., battery low, minor crack...)'**
  String get notesOnReturn;

  /// No description provided for @setFinalStatus.
  ///
  /// In en, this message translates to:
  /// **'Set Final Status'**
  String get setFinalStatus;

  /// No description provided for @reportMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Report Maintenance (Send for Repair)'**
  String get reportMaintenance;

  /// No description provided for @equipmentHistory.
  ///
  /// In en, this message translates to:
  /// **'Equipment History'**
  String get equipmentHistory;

  /// No description provided for @checkedOut.
  ///
  /// In en, this message translates to:
  /// **'Checked Out'**
  String get checkedOut;

  /// No description provided for @checkedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked In'**
  String get checkedIn;

  /// No description provided for @unknownEquipment.
  ///
  /// In en, this message translates to:
  /// **'Unknown Equipment'**
  String get unknownEquipment;

  /// No description provided for @itemName.
  ///
  /// In en, this message translates to:
  /// **'Item Name'**
  String get itemName;

  /// No description provided for @addInventoryItem.
  ///
  /// In en, this message translates to:
  /// **'Add to Inventory'**
  String get addInventoryItem;

  /// No description provided for @editInventoryItem.
  ///
  /// In en, this message translates to:
  /// **'Edit in Inventory'**
  String get editInventoryItem;

  /// No description provided for @deleteInventoryItem.
  ///
  /// In en, this message translates to:
  /// **'Delete from Inventory'**
  String get deleteInventoryItem;

  /// No description provided for @totalQuantity.
  ///
  /// In en, this message translates to:
  /// **'Total Quantity'**
  String get totalQuantity;

  /// No description provided for @availableQuantity.
  ///
  /// In en, this message translates to:
  /// **'Available Quantity'**
  String get availableQuantity;

  /// No description provided for @noInventoryItems.
  ///
  /// In en, this message translates to:
  /// **'No inventory items.'**
  String get noInventoryItems;

  /// No description provided for @inventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// No description provided for @quantityToCheckout.
  ///
  /// In en, this message translates to:
  /// **'Quantity to Checkout'**
  String get quantityToCheckout;

  /// No description provided for @quantityToReturn.
  ///
  /// In en, this message translates to:
  /// **'Quantity to Return'**
  String get quantityToReturn;

  /// No description provided for @quantityLost.
  ///
  /// In en, this message translates to:
  /// **'Quantity Lost/Damaged'**
  String get quantityLost;

  /// No description provided for @notEnoughStock.
  ///
  /// In en, this message translates to:
  /// **'Not in stock. Available Quantity: '**
  String get notEnoughStock;

  /// No description provided for @checkoutSuccess.
  ///
  /// In en, this message translates to:
  /// **'Checkout Successful'**
  String get checkoutSuccess;

  /// No description provided for @returnSuccess.
  ///
  /// In en, this message translates to:
  /// **'Return Successful'**
  String get returnSuccess;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @cannotBeGreaterThan.
  ///
  /// In en, this message translates to:
  /// **'Cannot be greater than '**
  String get cannotBeGreaterThan;

  /// No description provided for @quantityError.
  ///
  /// In en, this message translates to:
  /// **'Quantity to return cannot be greater than checked out quantity.'**
  String get quantityError;

  /// No description provided for @negativeQuantityError.
  ///
  /// In en, this message translates to:
  /// **'Quantity cannot be negative.'**
  String get negativeQuantityError;

  /// No description provided for @inventoryHistory.
  ///
  /// In en, this message translates to:
  /// **'Inventory History'**
  String get inventoryHistory;

  /// No description provided for @noHistoryFound.
  ///
  /// In en, this message translates to:
  /// **'No history found for this item.'**
  String get noHistoryFound;

  /// No description provided for @allRoles.
  ///
  /// In en, this message translates to:
  /// **'All Roles'**
  String get allRoles;

  /// No description provided for @manager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get manager;

  /// No description provided for @allManagers.
  ///
  /// In en, this message translates to:
  /// **'All Managers'**
  String get allManagers;

  /// No description provided for @filterByManager.
  ///
  /// In en, this message translates to:
  /// **'Filter by Manager'**
  String get filterByManager;

  /// No description provided for @editDailyNote.
  ///
  /// In en, this message translates to:
  /// **'Edit Daily Note'**
  String get editDailyNote;

  /// No description provided for @sortByMastery.
  ///
  /// In en, this message translates to:
  /// **'Sort by Mastery'**
  String get sortByMastery;

  /// No description provided for @sortByDate.
  ///
  /// In en, this message translates to:
  /// **'Sort by Date'**
  String get sortByDate;

  /// No description provided for @sortByLevel.
  ///
  /// In en, this message translates to:
  /// **'Sort by Level'**
  String get sortByLevel;

  /// No description provided for @sortByName.
  ///
  /// In en, this message translates to:
  /// **'Sort by Name'**
  String get sortByName;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @analyzeNotesNow.
  ///
  /// In en, this message translates to:
  /// **'Analyze Notes Now'**
  String get analyzeNotesNow;

  /// No description provided for @operations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get operations;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @reportGeneratedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Report generated successfully.'**
  String get reportGeneratedSuccessfully;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed. Please try again.'**
  String get exportFailed;

  /// No description provided for @exportStarting.
  ///
  /// In en, this message translates to:
  /// **'Exporting...'**
  String get exportStarting;

  /// No description provided for @exportBackup.
  ///
  /// In en, this message translates to:
  /// **'Export Backup'**
  String get exportBackup;

  /// No description provided for @importBackup.
  ///
  /// In en, this message translates to:
  /// **'Import Backup'**
  String get importBackup;

  /// No description provided for @aiRecommendation.
  ///
  /// In en, this message translates to:
  /// **'AI Recommendation'**
  String get aiRecommendation;

  /// No description provided for @inventoryList.
  ///
  /// In en, this message translates to:
  /// **'Inventory List'**
  String get inventoryList;

  /// No description provided for @selectTrainee.
  ///
  /// In en, this message translates to:
  /// **'Select Trainee'**
  String get selectTrainee;

  /// No description provided for @withAiAnalysis.
  ///
  /// In en, this message translates to:
  /// **'With AI Analysis'**
  String get withAiAnalysis;

  /// No description provided for @withoutAiAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Without AI Analysis'**
  String get withoutAiAnalysis;

  /// No description provided for @includeAiAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Include AI Analysis'**
  String get includeAiAnalysis;

  /// No description provided for @aiPerformanceAnalysis.
  ///
  /// In en, this message translates to:
  /// **'AI Performance Analysis'**
  String get aiPerformanceAnalysis;

  /// No description provided for @comprehensiveReport.
  ///
  /// In en, this message translates to:
  /// **'Comprehensive Report'**
  String get comprehensiveReport;

  /// No description provided for @reportGenerationFailed.
  ///
  /// In en, this message translates to:
  /// **'Report generation failed. Try again.'**
  String get reportGenerationFailed;

  /// No description provided for @generatingComprehensiveReport.
  ///
  /// In en, this message translates to:
  /// **'Generating comprehensive report. This may take a few minutes...'**
  String get generatingComprehensiveReport;

  /// No description provided for @showOnlyWithResults.
  ///
  /// In en, this message translates to:
  /// **'Show Trainings with Results Only'**
  String get showOnlyWithResults;

  /// No description provided for @moveToBottom.
  ///
  /// In en, this message translates to:
  /// **'Move to Bottom'**
  String get moveToBottom;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
