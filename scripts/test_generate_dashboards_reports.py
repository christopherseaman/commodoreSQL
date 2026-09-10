#!/usr/bin/env python3
"""Check generated dashboard navigation uses deployed and repository destinations."""

import unittest

try:
    import generate_dashboards_reports as reports
except ModuleNotFoundError:  # unittest discovery from the repository root
    from scripts import generate_dashboards_reports as reports


class DashboardReportTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rendered = reports.render()

    def test_dashboard_names_link_to_deployed_dashboards(self):
        ids, dashboards, _, _ = reports.load()
        for dashboard in dashboards:
            key = "dashboard_" + dashboard["path"].stem
            expected = f"### [{dashboard['meta']['name']}]({reports.METABASE_URL}/dashboard/{ids[key]})"
            self.assertIn(expected, self.rendered)

    def test_cards_and_models_retain_repository_links(self):
        ids, _, questions, models = reports.load()
        for stem in questions:
            self.assertIn(f"]({reports.METABASE_URL}/question/{ids[stem]})", self.rendered)
            self.assertIn(f"](metabase/questions/{stem}.sql)", self.rendered)
        for key in models:
            stem = key.removeprefix("model_")
            self.assertIn(f"]({reports.METABASE_URL}/model/{ids[key]})", self.rendered)
            self.assertIn(f"](metabase/models/{stem}.sql)", self.rendered)


if __name__ == "__main__":
    unittest.main()
