/// What Fred is told when a photo can't be kept. The error itself goes to
/// the log, never to the screen.
class PhotoProblems {
  const PhotoProblems._();

  static const cannotSave =
      "Couldn't save this photo. Check that your phone has free space, "
      'then try again.';
}
