@IsTest
private class SecurityBeatTest {

    // A brand-new user with no permission sets sees ZERO candidate data.
    // This is the platform's least-privilege default — the same wall the
    // agent user hit until access was deliberately granted.
    //
    // NOTE: this test deliberately inserts its own Contact BEFORE runAs
    // (visible in test context without SeeAllData) and asserts the admin
    // user CAN see it as a positive control. Without a real record and a
    // control, "the bare user sees nothing" would be true by construction
    // (a fresh test database has no Contacts for anyone) and would prove
    // nothing about actual security enforcement.
    @IsTest
    static void newUserWithNoGrantsSeesNothing() {
        Contact candidate = new Contact(LastName = 'SecurityBeatCandidate');
        insert candidate;

        // Positive control: the running (admin) test user can see the record.
        List<Contact> adminVisible = [SELECT Id FROM Contact WHERE Id = :candidate.Id];
        Assert.areEqual(1, adminVisible.size(), 'Admin test user should see the inserted contact');

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
                // Not blocked by object-access denial (no exception) — the
                // security bar is still met only if the specific inserted
                // record is absent from what this user can see.
                blocked = !containsId(visible, candidate.Id);
            } catch (System.QueryException e) {
                blocked = true; // object-level access denied outright
            }
            Assert.isTrue(blocked, 'A no-permission user should not see the candidate contact');
        }
    }

    private static Boolean containsId(List<Contact> records, Id targetId) {
        for (Contact c : records) {
            if (c.Id == targetId) {
                return true;
            }
        }
        return false;
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
