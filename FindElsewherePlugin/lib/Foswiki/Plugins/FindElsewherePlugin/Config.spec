# ---+ Extensions
# ---++ FindElsewherePlugin
# ---+++ CairoLegacyLinking
# **BOOLEAN**
# Fall back to pre-nested web topic linking (pre-Dakar release)
# this will link
#    * [[Arth's Checklist]] to ArthsChecklist
#    * [[MyNNA bugs/feature requests]] to MyNNABugsfeatureRequests
#    * [[6to4.enro.net]] to 6to4enronet
#  if those topics exist.
#
#  WARNING: this will slow down rendering.
$Foswiki::cfg{FindElsewherePlugin}{CairoLegacyLinking} = $FALSE;
