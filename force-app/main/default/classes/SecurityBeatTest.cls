@IsTest
private class SecurityBeatTest {

    // A brand-new user with no permission sets sees ZERO candidate data.
    // This is the platform's least-privilege default — the same wall the
    // agent user hit until access was deliberately granted.
    @IsTest
    static void newUserWithNoGrantsSeesNothing() {
        Profile minAccess = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        User bare = new User(
            Alias = 'zerop',
            Email = 'zero.priv@example.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'ZeroPriv',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = minAccess.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'zero.priv.' + System.currentTimeMillis() + '@example.invalid'
        );
        insert bare;

        System.runAs(bare) {
            Boolean blocked = false;
            try {
                List<Contact> visible = Database.query('SELECT Id FROM Contact WITH USER_MODE');
                blocked = visible.isEmpty();
            } catch (System.QueryException e) {
                blocked = true; // object-level access denied outright
            }
            Assert.isTrue(blocked, 'A no-permission user should see zero candidates');
        }
    }

    // The flow's declared run context (SystemModeWithoutSharing, one reviewable
    // line of XML) is the deliberate, auditable grant that lets the agent read
    // the roster.
    @IsTest(SeeAllData=true)
    static void declaredSystemContextSeesTheRoster() {
        Map<String, Object> inputs = new Map<String, Object>{ 'requestNote' => 'security beat' };
        Flow.Interview iv = Flow.Interview.createInterview('Get_Candidate_Profiles', inputs);
        iv.start();
        String profiles = (String) iv.getVariableValue('profilesText');
        Assert.isTrue(profiles != null && profiles.countMatches('--- ') > 0,
            'Flow in declared system context should return the roster');
    }
}
